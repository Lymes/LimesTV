//
//  PlayerViewModel.swift
//  LimesTV
//
//  Drives PlayerView: the phone-only carousel zap transition and banner. Actual
//  playback and channel zapping are delegated to the shared PlaybackController.
//

import AVKit
import Foundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class PlayerViewModel {
    private(set) var isShowingBanner = false

    /// Direction of the last zap: +1 for the next channel (swipe up), -1 for the
    /// previous one (swipe down). Drives the slide transition.
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

    @ObservationIgnored private let initialChannel: Channel
    @ObservationIgnored private let playback: PlaybackController
    @ObservationIgnored private let settings: AppSettings

    @ObservationIgnored private var slideGeneration = 0
    @ObservationIgnored private var bannerTask: Task<Void, Never>?

    init(initialChannel: Channel,
         playback: PlaybackController = .shared,
         settings: AppSettings = .shared) {
        self.initialChannel = initialChannel
        self.playback = playback
        self.settings = settings
    }

    /// The player and current channel come from the shared controller.
    var player: AVPlayer? { playback.player }
    var currentChannel: Channel { playback.currentChannel ?? initialChannel }

    // MARK: - Lifecycle

    func start() {
        Task {
            await playback.loadChannelsIfNeeded()
            playback.play(initialChannel)
        }
    }

    func stop() {
        bannerTask?.cancel()
        playback.stop()
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
            zap(by: dy < 0 ? 1 : -1)
            return false
        } else if isLandscape, dx > 80 {
            return true
        }
        return false
    }

    // MARK: - Zapping

    private func zap(by delta: Int) {
        // Freeze the current frame before swapping so it can cover the new
        // channel's load while both layers slide across.
        let snapshot = playback.snapshotCurrentFrame()
        lastZapDirection = delta
        playback.changeChannel(by: delta)
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
}
