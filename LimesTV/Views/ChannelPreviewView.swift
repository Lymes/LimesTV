//
//  ChannelPreviewView.swift
//  LimesTV
//
//  Full-screen placeholder shown for the neighbouring channel during an
//  interactive zap drag, before its live stream is loaded. Shows the channel
//  logo and name on a black background.
//

import SwiftUI

struct ChannelPreviewView: View {
    let viewModel: ChannelCellViewModel

    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 20) {
                logo
                    .frame(maxWidth: 240, maxHeight: 160)
                Text(viewModel.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(40)
        }
    }

    /// The channel logo, falling back to the app logo when unavailable.
    @ViewBuilder
    private var logo: some View {
        if let logoURL = viewModel.logoURL {
            AsyncImage(url: logoURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .empty:
                    ProgressView()
                default:
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
            .opacity(0.6)
    }
}
