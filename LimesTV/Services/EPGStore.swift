//
//  EPGStore.swift
//  LimesTV
//
//  Shared, observable store for the programme guide, used by both the channel
//  grid and the player. Downloads and indexes the guide, and answers "what's on
//  now / next" and full-schedule lookups for a channel.
//

import Foundation

@MainActor
@Observable
final class EPGStore {
    /// Shared instance used across the app.
    static let shared = EPGStore()

    /// Whether a guide has been successfully loaded at least once.
    private(set) var isLoaded = false

    /// Programmes indexed by a normalized channel-name key. The EPG source keys
    /// channels by display name, not by our tvg-id, so we match on names.
    private var programmesByKey: [String: [EPGProgramme]] = [:]

    @ObservationIgnored private let service = EPGService()
    @ObservationIgnored private var loadTask: Task<Bool, Never>?

    /// Loads the guide once per session, de-duplicating concurrent callers (the
    /// phone grid and the CarPlay scene both trigger this). Returns whether a
    /// guide is available afterwards.
    @discardableResult
    func loadIfNeeded() async -> Bool {
        if isLoaded { return true }
        if let loadTask { return await loadTask.value }

        let task = Task { () -> Bool in
            do {
                let guide = try await service.fetchGuide()
                programmesByKey = Self.indexByChannelName(guide)
                isLoaded = true
                return true
            } catch {
                return false
            }
        }
        loadTask = task
        let result = await task.value
        loadTask = nil
        return result
    }

    // MARK: - Lookups

    /// All programmes for `channel`, sorted by start time.
    func programmes(for channel: Channel) -> [EPGProgramme] {
        programmesByKey[Self.normalizedKey(channel.name)] ?? []
    }

    /// The programme on air at `date`, if the guide covers this channel.
    func currentProgramme(for channel: Channel, at date: Date = Date()) -> EPGProgramme? {
        programmes(for: channel).first { $0.start <= date && date < $0.stop }
    }

    /// The first programme starting after `date`.
    func nextProgramme(for channel: Channel, at date: Date = Date()) -> EPGProgramme? {
        programmes(for: channel).first { $0.start > date }
    }

    // MARK: - Indexing / matching

    /// Indexes the guide by normalized channel name. On collisions the richer
    /// schedule wins.
    private static func indexByChannelName(_ guide: EPGGuide) -> [String: [EPGProgramme]] {
        var result: [String: [EPGProgramme]] = [:]
        for (channelId, programmes) in guide.programmes {
            let key = normalizedKey(channelId)
            guard !key.isEmpty else { continue }
            if let existing = result[key], existing.count >= programmes.count { continue }
            result[key] = programmes
        }
        return result
    }

    /// Normalizes a channel name/id for fuzzy matching between the m3u channel
    /// names and the EPG's display-name based ids: strips the trailing channel
    /// number, the "I" country tag, HD/4K markers, symbols and accents.
    static func normalizedKey(_ raw: String) -> String {
        var value = raw.lowercased()
        value = value.replacingOccurrences(of: #"\s{2,}\d+\s*$"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\s+i\s*$"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\b(hd|fhd|uhd|4k|sd)\b"#, with: "", options: .regularExpression)
        value = value.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        return String(value.unicodeScalars.filter { $0.isASCII && CharacterSet.alphanumerics.contains($0) })
    }
}
