//
//  PlayerView.swift
//  LimesTV
//
//  Plays a channel's live stream using AVKit. Swipe up/down to change channel.
//

import SwiftUI
import AVKit

struct PlayerView: View {
    /// All channels available for surfing while the player is open.
    let channels: [Channel]

    /// Reports the channel currently on screen back to the list, so it can stay in sync.
    @Binding var lastViewedChannel: Channel?

    @State private var currentIndex: Int
    @State private var player: AVPlayer?
    @State private var isShowingBanner = false
    @State private var bannerTask: Task<Void, Never>?
    @State private var stallObserver: NSObjectProtocol?
    @State private var statusObserver: NSKeyValueObservation?

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dismiss) private var dismiss

    init(channels: [Channel], initialChannel: Channel, lastViewedChannel: Binding<Channel?>) {
        self.channels = channels
        _lastViewedChannel = lastViewedChannel
        _currentIndex = State(initialValue: channels.firstIndex(of: initialChannel) ?? 0)
    }

    /// The channel currently playing.
    private var channel: Channel { channels[currentIndex] }

    /// In landscape (compact height) the video fills the whole screen.
    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        VideoPlayer(player: player)
            .background(Color.black)
            .ignoresSafeArea(edges: isLandscape ? .all : .bottom)
            .overlay(alignment: .top) { channelBanner }
            .simultaneousGesture(channelSwipeGesture)
            .navigationTitle(channel.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(isLandscape ? .hidden : .visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.5), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .statusBarHidden(isLandscape)
            .persistentSystemOverlays(isLandscape ? .hidden : .automatic)
            .onAppear {
                configureAudioSession()
                lastViewedChannel = channel
                play(channel)
            }
            .onDisappear {
                bannerTask?.cancel()
                teardownObservers()
                player?.pause()
                player = nil
            }
    }

    /// Swipe up/down changes channel; swipe right goes back in landscape (where
    /// the system edge-swipe is disabled because the navigation bar is hidden).
    private var channelSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let dy = value.translation.height
                let dx = value.translation.width
                if abs(dy) > abs(dx) {
                    guard abs(dy) > 50 else { return }
                    changeChannel(by: dy < 0 ? 1 : -1)
                } else if isLandscape, dx > 80 {
                    dismiss()
                }
            }
    }

    /// A brief overlay showing the channel name when switching.
    @ViewBuilder
    private var channelBanner: some View {
        // In portrait the navigation bar already shows the channel name, so the
        // banner is only needed in landscape where the bar is hidden.
        if isShowingBanner && isLandscape {
            Text(channel.name)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.black.opacity(0.7), in: Capsule())
                .padding(.top, isLandscape ? 24 : 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// Moves `delta` channels away (wrapping around) and reloads the player.
    private func changeChannel(by delta: Int) {
        guard channels.count > 1 else { return }
        currentIndex = (currentIndex + delta + channels.count) % channels.count
        lastViewedChannel = channel
        play(channel)
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

    /// Shows the channel banner and hides it again after a short delay.
    private func showBanner() {
        bannerTask?.cancel()
        withAnimation { isShowingBanner = true }
        bannerTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation { isShowingBanner = false }
        }
    }

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
