//
//  ChannelCellViewModel.swift
//  LimesTV
//
//  Presentation logic for a single channel cell.
//

import Foundation

struct ChannelCellViewModel {
    let channel: Channel

    var name: String { channel.name }
    var logoURL: URL? { channel.logoURL }

    /// Name of the asset shown when no remote logo is available or it fails to load.
    var fallbackImageName: String { "LimeLogo" }
}
