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
}
