//
//  PlayerViewModel.swift
//  LimesTV
//
//  Drives PlayerView: the phone-only interactive zap carousel and banner. The
//  live video follows the finger; releasing past the halfway point commits the
//  channel change, otherwise it snaps back. Actual playback and channel zapping
//  are delegated to the shared PlaybackController.
//

import AVKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class PlayerViewModel {
    private(set) var isShowingBanner = false

    /// Whether the schedule (palinsesto) sheet is presented.
    var isShowingSchedule = false

    // MARK: - Interactive carousel state

    /// Vertical offset of the live player layer. Follows the finger during a
    /// drag; animates to 0 (snap back) or one viewport away (commit).
    private(set) var currentOffset: CGFloat = 0
    /// The neighbouring channel previewed on the incoming side while dragging,
    /// or `nil` when at rest. Not a live stream — shown as a logo/name card
    /// until the zap is committed and the player loads it.
    private(set) var incomingChannel: Channel?
    /// Vertical offset of the incoming preview card.
    private(set) var incomingOffset: CGFloat = 0
    /// Opacity of the incoming preview card, faded out once the new stream is in.
    private(set) var incomingOpacity: Double = 1

    /// Size of the player viewport, provided by the view so the drag knows how
    /// far a full page is.
    @ObservationIgnored var viewportSize: CGSize = .zero

    @ObservationIgnored private let initialChannel: Channel
    @ObservationIgnored private let playback = PlaybackController.shared
    @ObservationIgnored private let settings = AppSettings.shared
    @ObservationIgnored private let epg = EPGStore.shared

    /// Bumped on every gesture so a stale animation completion can bail out.
    @ObservationIgnored private var interactionGeneration = 0
    @ObservationIgnored private var bannerTask: Task<Void, Never>?

    /// Fraction of the viewport the drag must pass to commit the channel change.
    private let commitThreshold: CGFloat = 0.5

    init(initialChannel: Channel) {
        self.initialChannel = initialChannel
    }

    /// The player and current channel come from the shared controller.
    var player: AVPlayer? { playback.player }
    var currentChannel: Channel { playback.currentChannel ?? initialChannel }

    // MARK: - Programme guide (EPG)

    /// Full schedule for the current channel, for the palinsesto sheet.
    var scheduleProgrammes: [EPGProgramme] { epg.programmes(for: currentChannel) }

    /// Whether the current channel has any guide data (drives the button/status).
    var hasSchedule: Bool { !scheduleProgrammes.isEmpty }

    /// A one-line "now / next" summary, e.g.
    /// "Adesso: Tg1 · mancano 12 min · Prossimo: Porta a Porta alle 23:20".
    /// Returns `nil` when the guide doesn't cover this channel.
    func statusLine(at date: Date) -> String? {
        let current = epg.currentProgramme(for: currentChannel, at: date)
        let next = epg.nextProgramme(for: currentChannel, at: date)
        guard current != nil || next != nil else { return nil }

        var parts: [String] = []
        if let current {
            parts.append("Adesso: \(current.title)")
            let remaining = current.stop.timeIntervalSince(date)
            if remaining > 0 { parts.append("mancano \(Self.remainingString(remaining))") }
        }
        if let next {
            parts.append("Prossimo: \(next.title) alle \(Self.timeFormatter.string(from: next.start))")
        }
        return parts.joined(separator: " · ")
    }

    private static func remainingString(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval / 60))
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        return "\(minutes) min"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

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
        resetInteraction()
    }

    // MARK: - Gestures

    /// Live drag update. Moves the video with the finger and previews the
    /// neighbour it would zap to. Horizontal drags are ignored here so they can
    /// be handled as a dismiss on release.
    func dragChanged(translation: CGSize) {
        guard settings.isChannelTransitionEnabled else { return }
        guard abs(translation.height) >= abs(translation.width) else { return }
        let height = viewportSize.height
        guard height > 0 else { return }

        // Follow the finger, clamped to a single page in either direction.
        let offset = max(-height, min(height, translation.height))
        currentOffset = offset

        let delta = offset < 0 ? 1 : (offset > 0 ? -1 : 0)
        if delta == 0 {
            incomingChannel = nil
            return
        }
        incomingChannel = playback.channel(offsetBy: delta)
        // The preview enters from the opposite edge, trailing the finger.
        incomingOffset = (offset < 0 ? height : -height) + offset
        incomingOpacity = 1
    }

    /// Drag release. Returns `true` when the view should dismiss (rightward
    /// swipe in landscape). Otherwise commits or cancels the zap.
    func dragEnded(translation: CGSize, isLandscape: Bool) -> Bool {
        // Horizontal gesture: dismiss in landscape, and undo any partial drag.
        if abs(translation.width) > abs(translation.height) {
            if !currentOffset.isZero { cancelZap() }
            return isLandscape && translation.width > 80
        }

        guard settings.isChannelTransitionEnabled else {
            // Non-interactive fallback: a decisive swipe zaps instantly.
            if abs(translation.height) > 50 {
                zapInstantly(by: translation.height < 0 ? 1 : -1)
            }
            return false
        }

        let height = viewportSize.height
        guard height > 0, incomingChannel != nil else {
            cancelZap()
            return false
        }

        let progress = abs(currentOffset) / height
        if progress >= commitThreshold {
            commitZap(delta: currentOffset < 0 ? 1 : -1)
        } else {
            cancelZap()
        }
        return false
    }

    // MARK: - Zap resolution

    /// Finishes the carousel move, then swaps the live stream underneath the
    /// preview card and fades the card out once the new channel is playing.
    private func commitZap(delta: Int) {
        let height = viewportSize.height
        interactionGeneration += 1
        let generation = interactionGeneration

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            currentOffset = delta > 0 ? -height : height
            incomingOffset = 0
        } completion: { [weak self] in
            guard let self, self.interactionGeneration == generation else { return }
            self.playback.changeChannel(by: delta)

            // The live player is now on the new channel; drop it back to centre
            // beneath the still-covering preview card, without animating.
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { self.currentOffset = 0 }

            // Reveal the (loading) live channel by fading the card away.
            withAnimation(.easeOut(duration: 0.25)) {
                self.incomingOpacity = 0
            } completion: { [weak self] in
                guard let self, self.interactionGeneration == generation else { return }
                self.resetInteraction()
            }
        }
        showBanner()
    }

    /// Snaps everything back to the current channel with no change.
    private func cancelZap() {
        let height = viewportSize.height
        interactionGeneration += 1
        let generation = interactionGeneration
        let delta = currentOffset < 0 ? 1 : -1

        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            currentOffset = 0
            incomingOffset = delta > 0 ? height : -height
        } completion: { [weak self] in
            guard let self, self.interactionGeneration == generation else { return }
            self.resetInteraction()
        }
    }

    /// Immediate channel change used when the interactive carousel is disabled.
    private func zapInstantly(by delta: Int) {
        playback.changeChannel(by: delta)
        showBanner()
    }

    private func resetInteraction() {
        currentOffset = 0
        incomingOffset = 0
        incomingOpacity = 1
        incomingChannel = nil
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
