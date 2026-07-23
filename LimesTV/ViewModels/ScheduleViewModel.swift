//
//  ScheduleViewModel.swift
//  LimesTV
//
//  Presentation logic for the channel schedule (palinsesto) timeline.
//

import Foundation

struct ScheduleViewModel {
    let channelName: String
    /// Only the programme on air now and the upcoming ones — past programmes are
    /// dropped so the timeline opens at "now".
    let programmes: [EPGProgramme]

    init(channelName: String, programmes: [EPGProgramme], now: Date = Date()) {
        self.channelName = channelName
        self.programmes = programmes.filter { $0.stop > now }
    }

    /// Whether `programme` is on air at `date`.
    func isCurrent(_ programme: EPGProgramme, at date: Date) -> Bool {
        programme.start <= date && date < programme.stop
    }

    /// Whether `programme` has already ended by `date`.
    func isPast(_ programme: EPGProgramme, at date: Date) -> Bool {
        programme.stop <= date
    }

    /// Start time as "HH:mm".
    func timeString(_ programme: EPGProgramme) -> String {
        Self.timeFormatter.string(from: programme.start)
    }

    /// Progress [0, 1] through `programme` at `date`, or `nil` if not current.
    func progress(_ programme: EPGProgramme, at date: Date) -> Double? {
        guard isCurrent(programme, at: date) else { return nil }
        let total = programme.stop.timeIntervalSince(programme.start)
        guard total > 0 else { return nil }
        return min(max(date.timeIntervalSince(programme.start) / total, 0), 1)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
