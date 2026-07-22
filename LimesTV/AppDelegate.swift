//
//  AppDelegate.swift
//  LimesTV
//
//  Vends scene configurations. A SwiftUI App lifecycle doesn't hand the CarPlay
//  scene its delegate from Info.plist on its own, so we return the CarPlay scene
//  configuration here; other roles fall back to the default (SwiftUI window).
//

import CarPlay
import OSLog
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    private let log = Logger(subsystem: "com.lymes.LimesTV", category: "CarPlay")

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let role = connectingSceneSession.role
        log.log("configurationForConnecting role=\(role.rawValue, privacy: .public)")
        if role == .carTemplateApplication {
            log.log("Vending CarPlay scene configuration")
            let configuration = UISceneConfiguration(name: "CarPlay", sessionRole: role)
            configuration.delegateClass = CarPlaySceneDelegate.self
            return configuration
        }
        return UISceneConfiguration(name: nil, sessionRole: role)
    }
}
