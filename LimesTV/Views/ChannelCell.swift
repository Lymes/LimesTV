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
            ChannelLogoTileView(
                logoURL: viewModel.logoURL,
                fallbackImageName: viewModel.fallbackImageName,
                size: 120
            )

            Text(viewModel.name)
                .font(.subheadline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            if let programmeTitle = viewModel.programmeTitle {
                Text(programmeTitle)
                    .font(.caption2)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                if let progress = viewModel.programmeProgress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(.green)
                }
            }
        }
    }
}
