//
//  ChannelLogoTileView.swift
//  LimesTV
//
//  Loads a channel logo and renders it as a uniform, adaptive-background tile —
//  the same look used by the CarPlay list — so grid logos share a consistent
//  footprint regardless of shape.
//

import SwiftUI

struct ChannelLogoTileView: View {
    let logoURL: URL?
    let fallbackImageName: String
    let size: CGFloat

    @State private var tile: UIImage?

    var body: some View {
        Group {
            if let tile {
                Image(uiImage: tile)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: size * 0.2)
                    .fill(.regularMaterial)
                    .overlay(ProgressView())
            }
        }
        .frame(width: size, height: size)
        .task(id: logoURL) { await loadTile() }
    }

    private func loadTile() async {
        let base = await logo()
        let rendered = base?.channelTile(size: CGSize(width: size, height: size))
        // Only publish once (avoids flashing the placeholder back in on reuse).
        if let rendered { tile = rendered }
    }

    /// The downloaded logo, or the bundled fallback when unavailable.
    private func logo() async -> UIImage? {
        if let logoURL, let image = await ChannelLogoLoader.shared.image(for: logoURL) {
            return image
        }
        return UIImage(named: fallbackImageName)
    }
}
