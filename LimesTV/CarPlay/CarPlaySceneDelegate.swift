//
//  CarPlaySceneDelegate.swift
//  LimesTV
//
//  Entry point for the CarPlay scene. Referenced by name from Info.plist.
//

import CarPlay
import OSLog

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private let coordinator = CarPlayCoordinator()
    private let log = Logger(subsystem: "com.lymes.LimesTV", category: "CarPlay")

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        log.log("CarPlaySceneDelegate didConnect")
        coordinator.attach(to: interfaceController)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        coordinator.detach()
    }
}
