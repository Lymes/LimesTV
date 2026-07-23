//
//  ChannelLogoLoader.swift
//  LimesTV
//
//  Loads and caches channel logo images for surfaces that need a concrete
//  UIImage rather than SwiftUI's AsyncImage: the CarPlay channel list and the
//  Now Playing artwork.
//

import UIKit

actor ChannelLogoLoader {
    /// Shared cache used by both the CarPlay scene and the playback engine.
    static let shared = ChannelLogoLoader()

    private var cache: [URL: UIImage] = [:]
    private var tileCache: [String: UIImage] = [:]

    /// Returns the logo for `url`, downloading it once and reusing it thereafter.
    func image(for url: URL) async -> UIImage? {
        if let cached = cache[url] { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else {
            return nil
        }
        cache[url] = image
        return image
    }

    /// Returns the logo for `url` rendered as a uniform tile. The rendering runs
    /// on this actor's executor (off the main thread) and is cached, so grids and
    /// lists never build tiles on the main thread.
    func tile(for url: URL, size: CGSize) async -> UIImage? {
        let key = Self.tileKey(url.absoluteString, size)
        if let cached = tileCache[key] { return cached }
        guard let image = await image(for: url) else { return nil }
        let tile = image.channelTile(size: size)
        tileCache[key] = tile
        return tile
    }

    /// Same as `tile(for:size:)` but for a bundled asset (the fallback logo).
    func tile(forNamed name: String, size: CGSize) async -> UIImage? {
        let key = Self.tileKey("named:" + name, size)
        if let cached = tileCache[key] { return cached }
        guard let image = UIImage(named: name) else { return nil }
        let tile = image.channelTile(size: size)
        tileCache[key] = tile
        return tile
    }

    private static func tileKey(_ base: String, _ size: CGSize) -> String {
        "\(base)|\(Int(size.width))x\(Int(size.height))"
    }
}
