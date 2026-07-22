//
//  ChannelCellViewModel.swift
//  LimesTV
//
//  Presentation logic for a single channel cell.
//

import Foundation

struct ChannelCellViewModel {
    let channel: Channel
    /// The programme currently on air, if the guide covers this channel.
    let programme: EPGProgramme?

    init(channel: Channel, programme: EPGProgramme? = nil) {
        self.channel = channel
        self.programme = programme
    }

    var name: String { channel.name }
    var logoURL: URL? { channel.logoURL }

    /// Name of the asset shown when no remote logo is available or it fails to load.
    var fallbackImageName: String { "LimeLogo" }

    /// Title of the programme on air now, if known.
    var programmeTitle: String? { programme?.title }

    /// Progress [0, 1] through the current programme, for a thin progress bar.
    var programmeProgress: Double? {
        guard let programme else { return nil }
        let total = programme.stop.timeIntervalSince(programme.start)
        guard total > 0 else { return nil }
        return min(max(Date().timeIntervalSince(programme.start) / total, 0), 1)
    }
}
