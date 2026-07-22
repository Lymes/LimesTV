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

    /// Transient message shown at the bottom of the screen; `nil` hides it.
    private(set) var toastMessage: String?

    private let service: PlaylistService

    @ObservationIgnored private var toastTask: Task<Void, Never>?

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

    // MARK: - Programme guide (EPG)

    /// Downloads and parses the programme guide, then indexes it for the cells.
    /// Safe to run concurrently with channel loading; never blocks the UI.
    func loadEPG() async {
        let loaded = await EPGStore.shared.loadIfNeeded()
        showToast(loaded ? "Guida TV aggiornata" : "Guida TV non disponibile")
    }

    /// The programme currently on air for `channel`, if the guide covers it.
    func currentProgramme(for channel: Channel) -> EPGProgramme? {
        EPGStore.shared.currentProgramme(for: channel)
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }
}
