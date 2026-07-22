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

    init(initialChannel: Channel, lastViewedChannel: Binding<Channel?>) {
        _viewModel = State(initialValue: PlayerViewModel(initialChannel: initialChannel))
        _lastViewedChannel = lastViewedChannel
    }

    /// In landscape (compact height) the video fills the whole screen.
    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                PlayerContainerView(player: viewModel.player)
                    .offset(y: viewModel.currentOffset)

                // Preview of the neighbouring channel, trailing the finger in
                // from the opposite edge during an interactive zap drag.
                if let incoming = viewModel.incomingChannel {
                    ChannelPreviewView(viewModel: ChannelCellViewModel(channel: incoming))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(y: viewModel.incomingOffset)
                        .opacity(viewModel.incomingOpacity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.black)
            .clipped()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                viewModel.viewportSize = size
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
        .onChange(of: viewModel.currentChannel) { _, channel in
            lastViewedChannel = channel
        }
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    /// Drag up/down to zap: the video follows the finger and snaps back or
    /// completes on release. A rightward swipe goes back in landscape (where the
    /// system edge-swipe is disabled because the navigation bar is hidden).
    private var channelSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                viewModel.dragChanged(translation: value.translation)
            }
            .onEnded { value in
                if viewModel.dragEnded(translation: value.translation, isLandscape: isLandscape) {
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
