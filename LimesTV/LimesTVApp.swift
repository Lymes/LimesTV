//
//  LimesTVApp.swift
//  LimesTV
//
//  Created by leonid.mesentsev on 19/07/2026.
//

import SwiftUI

@main
struct LimesTVApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // Shared with the CarPlay scene and the PlaybackController.
    @State private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
        }
    }
}
