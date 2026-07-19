//
//  PlayerView.swift
//  LimesTV
//
//  Plays a channel's live stream using AVKit. Swipe up/down to change channel.
//

import SwiftUI
import AVKit

struct PlayerView: View {
    @State private var viewModel: PlayerViewModel

    /// Reports the channel currently on screen back to the list, so it can stay in sync.
    @Binding var lastViewedChannel: Channel?

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dismiss) private var dismiss

    init(channels: [Channel], initialChannel: Channel, lastViewedChannel: Binding<Channel?>, settings: AppSettings) {
        _viewModel = State(initialValue: PlayerViewModel(channels: channels, initialChannel: initialChannel, settings: settings))
        _lastViewedChannel = lastViewedChannel
    }

    /// In landscape (compact height) the video fills the whole screen.
    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VideoPlayer(player: viewModel.player)
                    .offset(y: viewModel.playerOffset)

                // Frozen last frame of the outgoing channel, sliding away. The
                // black background keeps it fully opaque so the swapping player
                // never shows through the letterbox margins.
                if let snapshot = viewModel.outgoingSnapshot {
                    Image(uiImage: snapshot)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background(Color.black)
                        .offset(y: viewModel.snapshotOffset)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.black)
            .clipped()
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                viewModel.viewportHeight = height
            }
        }
        .ignoresSafeArea(edges: isLandscape ? .all : .bottom)
        .overlay(alignment: .top) { channelBanner }
        .animation(.default, value: viewModel.isShowingBanner)
        .simultaneousGesture(channelSwipeGesture)
        .navigationTitle(viewModel.currentChannel.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isLandscape ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(Color.black.opacity(0.5), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .statusBarHidden(isLandscape)
        .persistentSystemOverlays(isLandscape ? .hidden : .automatic)
        .onAppear {
            viewModel.onChannelChange = { lastViewedChannel = $0 }
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    /// Swipe up/down changes channel; swipe right goes back in landscape (where
    /// the system edge-swipe is disabled because the navigation bar is hidden).
    private var channelSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                if viewModel.handleSwipe(translation: value.translation, isLandscape: isLandscape) {
                    dismiss()
                }
            }
    }

    /// A brief overlay showing the channel name when switching.
    @ViewBuilder
    private var channelBanner: some View {
        // In portrait the navigation bar already shows the channel name, so the
        // banner is only needed in landscape where the bar is hidden.
        if viewModel.isShowingBanner && isLandscape {
            Text(viewModel.currentChannel.name)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.black.opacity(0.7), in: Capsule())
                .padding(.top, 24)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
