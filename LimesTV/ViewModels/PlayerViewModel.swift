//
//  PlayerViewModel.swift
//  LimesTV
//
//  Drives PlayerView: playback, channel zapping and stall recovery.
//

import AVKit
import Foundation
import Observation

@MainActor
@Observable
final class PlayerViewModel {
    let channels: [Channel]
    private(set) var currentIndex: Int
    private(set) var player: AVPlayer?
    private(set) var isShowingBanner = false

    /// Reports the channel currently on screen so the list can stay in sync.
    var onChannelChange: ((Channel) -> Void)?

    @ObservationIgnored private var stallObserver: NSObjectProtocol?
    @ObservationIgnored private var statusObserver: NSKeyValueObservation?
    @ObservationIgnored private var bannerTask: Task<Void, Never>?

    init(channels: [Channel], initialChannel: Channel) {
        self.channels = channels
        self.currentIndex = channels.firstIndex(of: initialChannel) ?? 0
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
        currentIndex = (currentIndex + delta + channels.count) % channels.count
        onChannelChange?(currentChannel)
        play(currentChannel)
        showBanner()
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
