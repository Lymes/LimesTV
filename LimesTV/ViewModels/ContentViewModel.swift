//
//  ContentViewModel.swift
//  LimesTV
//
//  Drives ContentView: loading, searching and tracking the channel list.
//

import Foundation
import Observation

@MainActor
@Observable
final class ContentViewModel {
    private(set) var channels: [Channel] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// Current search query. Bound from the view's search field.
    var searchText = ""
    /// The channel last shown in the player, used to keep the list in sync.
    var lastViewedChannel: Channel?
    /// Whether the settings sheet is presented.
    var isShowingSettings = false

    private let service: PlaylistService

    init(service: PlaylistService = PlaylistService()) {
        self.service = service
    }

    /// Channels matching the current search query.
    var filteredChannels: [Channel] {
        guard !searchText.isEmpty else { return channels }
        return channels.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// Loads channels only once (used by the initial `.task`).
    func loadChannelsIfNeeded() async {
        guard channels.isEmpty else { return }
        await loadChannels()
    }

    /// Loads (or reloads) the bundled channels.
    func loadChannels() async {
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
