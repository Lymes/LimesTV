//
//  AppRouter.swift
//  LimesTV
//
//  Shared navigation state for the main SwiftUI scene, so other scenes (CarPlay)
//  can drive the phone app — e.g. selecting a channel on the car display opens
//  that channel's player on the phone.
//

import Foundation

@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    /// Channels pushed on the main navigation stack.
    var path: [Channel] = []

    /// Opens the player for `channel`, replacing any current navigation.
    func openChannel(_ channel: Channel) {
        path = [channel]
    }
}
