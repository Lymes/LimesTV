//
//  ContentView.swift
//  LimesTV
//
//  Created by leonid.mesentsev on 19/07/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = ContentViewModel()
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var router = AppRouter.shared
        NavigationStack(path: $router.path) {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading channels…")
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Couldn't load channels", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Retry") { Task { await viewModel.loadChannels() } }
                    }
                } else {
                    channelGrid
                }
            }
            .navigationTitle("TV Channels")
            .navigationDestination(for: Channel.self) { channel in
                PlayerView(
                    initialChannel: channel,
                    lastViewedChannel: $viewModel.lastViewedChannel
                )
            }
            .searchable(text: $viewModel.searchText, prompt: "Search channels")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.isShowingSettings) {
            SettingsView(settings: appSettings)
        }
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toastMessage {
                ToastView(message: toast)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.toastMessage)
        .task {
            await viewModel.loadChannelsIfNeeded()
        }
        .task {
            // Refresh the programme guide on every launch, without blocking the UI.
            await viewModel.loadEPG()
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]

    @ViewBuilder
    private var channelGrid: some View {
        if viewModel.filteredChannels.isEmpty {
            ContentUnavailableView.search(text: viewModel.searchText)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    // Re-render each minute so the "on now" title and progress
                    // bar on every cell stay current.
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.filteredChannels) { channel in
                                NavigationLink(value: channel) {
                                    ChannelCell(viewModel: ChannelCellViewModel(
                                        channel: channel,
                                        programme: viewModel.currentProgramme(for: channel)
                                    ))
                                }
                                .buttonStyle(.plain)
                                .id(channel.id)
                            }
                        }
                        .padding()
                    }
                }
                // Keep the list aligned with the channel last watched in the player.
                .onChange(of: viewModel.lastViewedChannel) { _, newValue in
                    guard let newValue else { return }
                    proxy.scrollTo(newValue.id, anchor: .center)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppSettings())
}
