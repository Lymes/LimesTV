//
//  PlaybackController.swift
//  LimesTV
//
//  App-level playback engine shared by the phone player and CarPlay. Owns the
//  single AVPlayer, the channel list and channel zapping, so both front-ends
//  drive the same stream.
//

import AVKit
import Foundation
import MediaPlayer
import Observation
import UIKit

@MainActor
@Observable
final class PlaybackController {
    /// Shared instance used by both the SwiftUI scene and the CarPlay scene.
    static let shared = PlaybackController(settings: .shared)

    private(set) var channels: [Channel] = []
    private(set) var currentIndex = 0
    private(set) var player: AVPlayer?

    /// The channel currently playing, or `nil` before any channel is loaded.
    var currentChannel: Channel? {
        channels.indices.contains(currentIndex) ? channels[currentIndex] : nil
    }

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let service = PlaylistService()
    @ObservationIgnored private var stallObserver: NSObjectProtocol?
    @ObservationIgnored private var statusObserver: NSKeyValueObservation?
    @ObservationIgnored private var timeControlObserver: NSKeyValueObservation?
    @ObservationIgnored private var remoteCommandsConfigured = false

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Channel list

    /// Loads the bundled channels once. Safe to call from either scene.
    func loadChannelsIfNeeded() async {
        guard channels.isEmpty else { return }
        channels = (try? await service.loadChannels()) ?? []
    }

    // MARK: - Playback

    /// Plays the given channel (must belong to `channels`).
    func play(_ channel: Channel) {
        guard let index = channels.firstIndex(of: channel) else { return }
        currentIndex = index
        startPlayback()
    }

    /// Advances by `delta` channels, wrapping around.
    func changeChannel(by delta: Int) {
        guard channels.count > 1 else { return }
        currentIndex = (currentIndex + delta + channels.count) % channels.count
        startPlayback()
    }

    func next() { changeChannel(by: 1) }
    func previous() { changeChannel(by: -1) }

    /// Returns the channel `delta` positions away from the current one, wrapping
    /// around, without changing playback. Used to preview the neighbour channel
    /// during an interactive zap drag.
    func channel(offsetBy delta: Int) -> Channel? {
        guard channels.count > 1 else { return nil }
        let index = (currentIndex + delta + channels.count) % channels.count
        return channels[index]
    }

    func stop() {
        teardownObservers()
        timeControlObserver?.invalidate()
        timeControlObserver = nil
        player?.pause()
        player = nil
    }

    /// Loads and starts playback of the current channel. A single `AVPlayer` is
    /// reused across channels (its item is swapped) to avoid tearing down the
    /// media pipeline on every zap.
    private func startPlayback() {
        guard let channel = currentChannel else { return }
        configureAudioSession()
        configureRemoteCommandsIfNeeded()
        teardownObservers()

        let item = AVPlayerItem(url: channel.streamURL)
        applyQualityCap(to: item)

        let activePlayer: AVPlayer
        if let player {
            activePlayer = player
            activePlayer.replaceCurrentItem(with: item)
        } else {
            activePlayer = AVPlayer(playerItem: item)
            // Don't wait to minimise stalls, otherwise the player can show the
            // first frame and then wait forever instead of starting playback.
            activePlayer.automaticallyWaitsToMinimizeStalling = false
            // Allow AirPlay video routing so a parked, video-capable CarPlay
            // vehicle can show the stream on the car display.
            activePlayer.allowsExternalPlayback = true
            activePlayer.usesExternalPlaybackWhileExternalScreenIsActive = true
            player = activePlayer

            // Keep Now Playing (and thus CarPlay) in sync with play/pause,
            // whichever front-end triggered it.
            timeControlObserver = activePlayer.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.updateNowPlayingPlaybackState() }
            }
        }

        // Kick off playback only once the item is actually ready.
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
        updateNowPlaying()
    }

    /// Applies the user's optional quality cap. `.auto` leaves defaults untouched.
    private func applyQualityCap(to item: AVPlayerItem) {
        let quality = settings.videoQuality
        if let maxResolution = quality.maximumResolution {
            item.preferredMaximumResolution = maxResolution
        }
        if quality.peakBitRate > 0 {
            item.preferredPeakBitRate = quality.peakBitRate
        }
    }

    private func teardownObservers() {
        statusObserver?.invalidate()
        statusObserver = nil
        if let stallObserver {
            NotificationCenter.default.removeObserver(stallObserver)
            self.stallObserver = nil
        }
    }

    // MARK: - Now Playing / remote commands

    private func updateNowPlaying() {
        guard let channel = currentChannel else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: channel.name,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue
        ]

        // Attach the channel logo as artwork once it has loaded, unless the user
        // has already zapped to a different channel in the meantime.
        guard let logoURL = channel.logoURL else { return }
        Task {
            guard let image = await ChannelLogoLoader.shared.image(for: logoURL),
                  currentChannel?.id == channel.id else { return }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            info[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    /// Mirrors the player's actual play/pause state into Now Playing so both the
    /// phone player and the CarPlay Now Playing screen show the same state.
    private func updateNowPlayingPlaybackState() {
        guard let player else { return }
        let isPlaying = player.timeControlStatus == .playing
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    private func configureRemoteCommandsIfNeeded() {
        guard !remoteCommandsConfigured else { return }
        remoteCommandsConfigured = true
        let center = MPRemoteCommandCenter.shared()
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        center.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            return .success
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
