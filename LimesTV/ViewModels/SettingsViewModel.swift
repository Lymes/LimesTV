//
//  SettingsViewModel.swift
//  LimesTV
//
//  Presentation logic for SettingsView, backed by the shared AppSettings.
//

import Foundation

@MainActor
@Observable
final class SettingsViewModel {
    @ObservationIgnored private let settings: AppSettings

    /// Quality options offered by the picker.
    let qualityOptions = VideoQuality.allCases

    init(settings: AppSettings) {
        self.settings = settings
    }

    var videoQuality: VideoQuality {
        get { settings.videoQuality }
        set { settings.videoQuality = newValue }
    }

    var isChannelTransitionEnabled: Bool {
        get { settings.isChannelTransitionEnabled }
        set { settings.isChannelTransitionEnabled = newValue }
    }
}
