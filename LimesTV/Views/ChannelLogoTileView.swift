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
        // Tiles are rendered on the loader's actor (off the main thread) so the
        // grid stays scrollable while logos load.
        let dimension = CGSize(width: size, height: size)
        if let logoURL,
           let rendered = await ChannelLogoLoader.shared.tile(for: logoURL, size: dimension) {
            tile = rendered
            return
        }
        tile = await ChannelLogoLoader.shared.tile(forNamed: fallbackImageName, size: dimension)
    }
}
