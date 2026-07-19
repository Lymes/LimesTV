//
//  ChannelCell.swift
//  LimesTV
//
//  A single channel tile in the grid.
//

import SwiftUI

struct ChannelCell: View {
    let viewModel: ChannelCellViewModel

    var body: some View {
        VStack(spacing: 10) {
            logo
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            Text(viewModel.name)
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
        if let logoURL = viewModel.logoURL {
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
        Image(viewModel.fallbackImageName)
            .resizable()
            .scaledToFit()
            .padding(8)
            .opacity(0.6)
    }
}
