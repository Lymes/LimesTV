//
//  EPGProgramme.swift
//  LimesTV
//
//  A single TV programme (show) parsed from the XMLTV electronic programme
//  guide.
//

import Foundation

struct EPGProgramme: Sendable, Hashable {
    /// XMLTV channel id this programme belongs to (matches `Channel.id` / tvg-id).
    let channelId: String
    let title: String
    let description: String?
    let start: Date
    let stop: Date
}
