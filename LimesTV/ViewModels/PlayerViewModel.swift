//
//  PlayerViewModel.swift
//  LimesTV
//
//  Drives PlayerView: playback, channel zapping and stall recovery.
//

import AVKit
import CoreImage
import Foundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class PlayerViewModel {
    private let channels: [Channel]
    private var currentIndex: Int
    private(set) var player: AVPlayer?
    private(set) var isShowingBanner = false

    /// Direction of the last zap: +1 when moving to the next channel (swipe up),
    /// -1 for the previous one (swipe down). Drives the slide transition.
    private var lastZapDirection = 1

    /// Frozen last frame of the outgoing channel, shown on top of the (loading)
    /// new channel while both slide across during a zap.
    private(set) var outgoingSnapshot: UIImage?
    /// Vertical offset of the live player layer during the zap slide.
    private(set) var playerOffset: CGFloat = 0
    /// Vertical offset of the frozen snapshot layer during the zap slide.
    private(set) var snapshotOffset: CGFloat = 0

    /// Height of the player viewport, provided by the view so the slide knows
    /// how far off screen to start/finish.
    @ObservationIgnored var viewportHeight: CGFloat = 0

    private let slideDuration = 0.35

    /// Reports the channel currently on screen so the list can stay in sync.
    var onChannelChange: ((Channel) -> Void)?

    @ObservationIgnored private var stallObserver: NSObjectProtocol?
    @ObservationIgnored private var statusObserver: NSKeyValueObservation?
    @ObservationIgnored private var bannerTask: Task<Void, Never>?
    @ObservationIgnored private var videoOutput: AVPlayerItemVideoOutput?
    @ObservationIgnored private let ciContext = CIContext()
    /// Identifies the current slide so a superseded one can't clear the frame
    /// of a newer zap when its completion fires late.
    @ObservationIgnored private var slideGeneration = 0
    @ObservationIgnored private let settings: AppSettings

    init(channels: [Channel], initialChannel: Channel, settings: AppSettings) {
        self.channels = channels
        self.currentIndex = channels.firstIndex(of: initialChannel) ?? 0
        self.settings = settings
    }

    /// The channel currently playing.
    var currentChannel: Channel { channels[currentIndex] }

    // MARK: - Lifecycle

    func start() {
        configureAudioSession()
        onChannelChange?(currentChannel)
        play(currentChannel)
    }

    func stop() {
        bannerTask?.cancel()
        teardownObservers()
        player?.pause()
        player = nil
        videoOutput = nil
        outgoingSnapshot = nil
    }

    // MARK: - Gestures

    /// Handles a drag gesture. Swipe up/down zaps channels; a rightward swipe in
    /// landscape requests dismissal. Returns `true` when the view should dismiss.
    func handleSwipe(translation: CGSize, isLandscape: Bool) -> Bool {
        let dy = translation.height
        let dx = translation.width
        if abs(dy) > abs(dx) {
            guard abs(dy) > 50 else { return false }
            changeChannel(by: dy < 0 ? 1 : -1)
            return false
        } else if isLandscape, dx > 80 {
            return true
        }
        return false
    }

    // MARK: - Zapping

    /// Moves `delta` channels away (wrapping around) and reloads the player.
    private func changeChannel(by delta: Int) {
        guard channels.count > 1 else { return }
        // Freeze the current frame before swapping the item so it can cover the
        // new channel's load while both layers slide across.
        let snapshot = snapshotCurrentFrame()
        lastZapDirection = delta
        currentIndex = (currentIndex + delta + channels.count) % channels.count
        onChannelChange?(currentChannel)
        play(currentChannel)
        // Slide only when enabled and a frame was captured to cover the swap;
        // otherwise a plain cut avoids flicking an empty layer across the screen.
        if let snapshot, settings.isChannelTransitionEnabled {
            beginZapSlide(snapshot: snapshot)
        }
        showBanner()
    }

    /// Runs the carousel slide: the frozen snapshot leaves one edge while the
    /// live player enters from the opposite one, following the swipe direction.
    ///
    /// The starting positions (snapshot covering, player off screen) are applied
    /// in the *same* update as the item swap, so no blank frame is ever shown;
    /// the animation itself is kicked off on the next tick so those positions
    /// render first.
    private func beginZapSlide(snapshot: UIImage) {
        guard viewportHeight > 0 else { return }
        let height = viewportHeight
        let goingUp = lastZapDirection > 0
        slideGeneration += 1
        let generation = slideGeneration

        var setup = Transaction()
        setup.disablesAnimations = true
        withTransaction(setup) {
            outgoingSnapshot = snapshot
            playerOffset = goingUp ? height : -height
            snapshotOffset = 0
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            withAnimation(.easeInOut(duration: self.slideDuration)) {
                self.playerOffset = 0
                self.snapshotOffset = goingUp ? -height : height
            } completion: { [weak self] in
                // Ignore if a newer zap has already taken over the slide.
                guard let self, self.slideGeneration == generation else { return }
                self.outgoingSnapshot = nil
                self.snapshotOffset = 0
            }
        }
    }

    /// Loads and starts playback of the given channel.
    ///
    /// A single `AVPlayer` is reused across channels (its item is swapped) to
    /// avoid tearing down/recreating the media XPC connection on every zap.
    /// The freeze-on-first-frame issue is handled by disabling the stall wait
    /// and only starting playback once the item is `.readyToPlay`.
    private func play(_ channel: Channel) {
        teardownObservers()

        let item = AVPlayerItem(url: channel.streamURL)
        applyQualityCap(to: item)

        // Tap the video frames so we can grab a still for the zap transition.
        let output = AVPlayerItemVideoOutput(
            pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        item.add(output)
        videoOutput = output

        let activePlayer: AVPlayer
        if let player {
            activePlayer = player
            activePlayer.replaceCurrentItem(with: item)
        } else {
            activePlayer = AVPlayer(playerItem: item)
            // Don't wait to minimise stalls, otherwise the player can show the
            // first frame and then wait forever instead of starting playback.
            activePlayer.automaticallyWaitsToMinimizeStalling = false
            player = activePlayer
        }

        // Kick off playback only once the item is actually ready. Calling play()
        // while the item is still loading is what left it frozen on a still frame
        // until a manual stop/play.
        statusObserver = item.observe(\.status, options: [.new]) { observedItem, _ in
            if observedItem.status == .readyToPlay {
                activePlayer.play()
            }
        }

        // Auto-recover from stalls that happen after playback has started.
        stallObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { _ in
            activePlayer.play()
        }

        activePlayer.play()
    }

    /// Applies the user's optional quality cap to a freshly created item. `.auto`
    /// leaves the defaults untouched so AVFoundation streams the best variant.
    private func applyQualityCap(to item: AVPlayerItem) {
        let quality = settings.videoQuality
        if let maxResolution = quality.maximumResolution {
            item.preferredMaximumResolution = maxResolution
        }
        if quality.peakBitRate > 0 {
            item.preferredPeakBitRate = quality.peakBitRate
        }
    }

    /// Grabs the frame currently on screen as a still image, used as the
    /// outgoing layer of the zap slide.
    private func snapshotCurrentFrame() -> UIImage? {
        guard let videoOutput, let item = player?.currentItem else { return nil }
        let time = item.currentTime()
        guard let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else {
            return nil
        }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func teardownObservers() {
        statusObserver?.invalidate()
        statusObserver = nil
        if let stallObserver {
            NotificationCenter.default.removeObserver(stallObserver)
            self.stallObserver = nil
        }
    }

    // MARK: - Banner

    /// Shows the channel banner and hides it again after a short delay.
    private func showBanner() {
        bannerTask?.cancel()
        isShowingBanner = true
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.isShowingBanner = false
        }
    }

    // MARK: - Audio

    /// Enables audio playback even when the device's silent switch is on.
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
}
