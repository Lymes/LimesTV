//
//  ContentView.swift
//  LimesTV
//
//  Created by leonid.mesentsev on 19/07/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var channels: [Channel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var lastViewedChannel: Channel?

    private let service = PlaylistService()

    private var filteredChannels: [Channel] {
        guard !searchText.isEmpty else { return channels }
        return channels.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading channels…")
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Couldn't load channels", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Retry") { Task { await loadChannels() } }
                    }
                } else {
                    channelGrid
                }
            }
            .navigationTitle("TV Channels")
            .navigationDestination(for: Channel.self) { channel in
                // Zap through the full lineup, even when the list is filtered by search.
                PlayerView(channels: channels,
                           initialChannel: channel,
                           lastViewedChannel: $lastViewedChannel)
            }
            .searchable(text: $searchText, prompt: "Search channels")
        }
        .preferredColorScheme(.dark)
        .task {
            if channels.isEmpty { await loadChannels() }
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]

    @ViewBuilder
    private var channelGrid: some View {
        if filteredChannels.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredChannels) { channel in
                            NavigationLink(value: channel) {
                                ChannelCell(channel: channel)
                            }
                            .buttonStyle(.plain)
                            .id(channel.id)
                        }
                    }
                    .padding()
                }
                // Keep the list aligned with the channel last watched in the player.
                .onChange(of: lastViewedChannel) { _, newValue in
                    guard let newValue else { return }
                    proxy.scrollTo(newValue.id, anchor: .center)
                }
            }
        }
    }

    private func loadChannels() async {
        isLoading = true
        errorMessage = nil
        do {
            channels = try await service.loadChannels()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct ChannelCell: View {
    let channel: Channel

    var body: some View {
        VStack(spacing: 10) {
            logo
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            Text(channel.name)
                .font(.subheadline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
    }

    /// Shows the channel logo, falling back to the app logo when the URL is
    /// missing or the image fails to load (no lingering spinner in those cases).
    @ViewBuilder
    private var logo: some View {
        if let logoURL = channel.logoURL {
            AsyncImage(url: logoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .empty:
                    ProgressView()
                case .failure:
                    fallbackLogo
                @unknown default:
                    fallbackLogo
                }
            }
        } else {
            fallbackLogo
        }
    }

    private var fallbackLogo: some View {
        Image("LimeLogo")
            .resizable()
            .scaledToFit()
            .padding(8)
            .opacity(0.6)
    }
}

#Preview {
    ContentView()
}
