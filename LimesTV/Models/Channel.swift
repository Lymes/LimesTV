//
//  Channel.swift
//  LimesTV
//
//  Model representing a single IPTV channel parsed from an M3U playlist.
//

import Foundation

struct Channel: Identifiable, Hashable {
    let id: String
    let name: String
    let logoURL: URL?
    let streamURL: URL
    let group: String?
}
