//
//  LimesTVApp.swift
//  LimesTV
//
//  Created by leonid.mesentsev on 19/07/2026.
//

import SwiftUI

@main
struct LimesTVApp: App {
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
        }
    }
}
