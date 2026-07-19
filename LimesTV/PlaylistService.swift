//
//  PlaylistService.swift
//  LimesTV
//
//  Fetches and parses the Free-TV/IPTV Italian channel playlist (M3U format).
//

import Foundation

enum PlaylistError: Error {
    case resourceMissing
}

struct PlaylistService {
    /// Playlists bundled with the app, loaded and merged in order.
    static let bundledResourceExtension = "m3u8"
    static let bundledResourceNames = ["playlist_italy", "ucraina"]

    /// Reads all bundled playlists and returns the merged, de-duplicated channels. No network access.
    func loadChannels() async throws -> [Channel] {
        var channels: [Channel] = []
        var seenStreamURLs = Set<URL>()

        for name in Self.bundledResourceNames {
            guard let url = Bundle.main.url(forResource: name,
                                            withExtension: Self.bundledResourceExtension) else {
                continue
            }

            let data = try Data(contentsOf: url)
            let text = String(decoding: data, as: UTF8.self)
            for channel in Self.parse(text) where seenStreamURLs.insert(channel.streamURL).inserted {
                channels.append(channel)
            }
        }

        guard !channels.isEmpty else { throw PlaylistError.resourceMissing }
        return channels
    }

    /// Parses M3U content into channels. Each channel is described by an
    /// `#EXTINF` metadata line immediately followed by its stream URL.
    static func parse(_ text: String) -> [Channel] {
        var channels: [Channel] = []
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)

        var pendingInfo: String?

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("#EXTINF") {
                pendingInfo = line
            } else if line.hasPrefix("#") || line.isEmpty {
                continue
            } else if let info = pendingInfo, let streamURL = URL(string: line) {
                let name = extractName(from: info)
                let channel = Channel(
                    id: attribute("tvg-id", in: info).flatMap { $0.isEmpty ? nil : $0 } ?? line,
                    name: name,
                    logoURL: attribute("tvg-logo", in: info).flatMap(URL.init(string:)),
                    streamURL: streamURL,
                    group: attribute("group-title", in: info)
                )
                channels.append(channel)
                pendingInfo = nil
            }
        }

        return channels
    }

    /// Extracts the display name, which appears after the final comma on the `#EXTINF` line.
    private static func extractName(from info: String) -> String {
        if let commaIndex = info.lastIndex(of: ",") {
            let name = info[info.index(after: commaIndex)...].trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { return name }
        }
        return attribute("tvg-name", in: info) ?? "Unknown"
    }

    /// Reads a `key="value"` attribute out of an `#EXTINF` line.
    private static func attribute(_ key: String, in info: String) -> String? {
        guard let keyRange = info.range(of: "\(key)=\"") else { return nil }
        let valueStart = keyRange.upperBound
        guard let closingQuote = info[valueStart...].firstIndex(of: "\"") else { return nil }
        return String(info[valueStart..<closingQuote])
    }
}
