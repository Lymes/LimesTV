//
//  AppSettings.swift
//  LimesTV
//
//  App-wide, user-adjustable settings persisted in UserDefaults.
//

import CoreGraphics
import Foundation
import Observation

/// Optional cap applied to playback quality. `.auto` lets AVFoundation pick the
/// best available variant; the others trade some quality for lower network and
/// battery use (network is the dominant energy cost during streaming).
enum VideoQuality: String, CaseIterable, Identifiable {
    case auto
    case high
    case medium
    case low

    var id: String { rawValue }

    /// User-facing label.
    var label: String {
        switch self {
        case .auto: "Auto (best available)"
        case .high: "High (1080p)"
        case .medium: "Medium (720p)"
        case .low: "Low (480p)"
        }
    }

    /// Upper bound on decoded resolution, or `nil` for no limit.
    var maximumResolution: CGSize? {
        switch self {
        case .auto: nil
        case .high: CGSize(width: 1920, height: 1080)
        case .medium: CGSize(width: 1280, height: 720)
        case .low: CGSize(width: 854, height: 480)
        }
    }

    /// Upper bound on bit rate in bits/second, or `0` for no limit.
    var peakBitRate: Double {
        switch self {
        case .auto: 0
        case .high: 6_000_000
        case .medium: 3_000_000
        case .low: 1_200_000
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    /// Shared instance used across the SwiftUI and CarPlay scenes.
    static let shared = AppSettings()

    /// Preferred playback quality cap. Defaults to `.auto` to preserve quality.
    var videoQuality: VideoQuality {
        didSet { defaults.set(videoQuality.rawValue, forKey: Keys.videoQuality) }
    }

    /// Whether zapping plays the sliding carousel transition.
    var isChannelTransitionEnabled: Bool {
        didSet { defaults.set(isChannelTransitionEnabled, forKey: Keys.channelTransition) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.videoQuality = defaults.string(forKey: Keys.videoQuality)
            .flatMap(VideoQuality.init(rawValue:)) ?? .auto
        // Enabled by default when the user has never changed it.
        self.isChannelTransitionEnabled = defaults.object(forKey: Keys.channelTransition) as? Bool ?? true
    }

    private enum Keys {
        static let videoQuality = "videoQuality"
        static let channelTransition = "channelTransitionEnabled"
    }
}
