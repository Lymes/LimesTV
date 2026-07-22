//
//  EPGGuide.swift
//  LimesTV
//
//  The parsed electronic programme guide: programmes grouped by channel id.
//  Pure data; lookups (e.g. "what's on now") live in the view model.
//

import Foundation

struct EPGGuide: Sendable {
    /// Programmes keyed by XMLTV channel id, each list sorted by start time.
    let programmes: [String: [EPGProgramme]]

    static let empty = EPGGuide(programmes: [:])
}
