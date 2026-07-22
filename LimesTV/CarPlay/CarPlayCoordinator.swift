//
//  CarPlayCoordinator.swift
//  LimesTV
//
//  Builds the CarPlay channel list and drives playback through the shared
//  PlaybackController. Acts as the "view model" for the CarPlay scene.
//

import CarPlay
import OSLog
import UIKit

@MainActor
final class CarPlayCoordinator: NSObject {
    private let playback = PlaybackController.shared
    private var interfaceController: CPInterfaceController?
    private let listTemplate = CPListTemplate(title: "LimesTV", sections: [])
    private let log = Logger(subsystem: "com.lymes.LimesTV", category: "CarPlay")

    /// Called when the CarPlay screen connects. Sets the root template
    /// synchronously so CarPlay always has content, then fills in the channels.
    func attach(to interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        interfaceController.delegate = self
        log.log("CarPlay didConnect")

        // Set the root template immediately: CarPlay shows a blank screen if the
        // root isn't set promptly, so we can't wait for the async channel load.
        listTemplate.updateSections(makeSections())
        interfaceController.setRootTemplate(listTemplate, animated: false) { [log] success, error in
            log.log("setRootTemplate success=\(success) error=\(String(describing: error))")
        }

        // Mirror phone-app navigation onto the CarPlay stack.
        observeRouter()

        Task {
            await playback.loadChannelsIfNeeded()
            log.log("Loaded \(self.playback.channels.count) channels")
            listTemplate.updateSections(makeSections())

            // Fill in the "on now" subtitles once the guide is available.
            await EPGStore.shared.loadIfNeeded()
            listTemplate.updateSections(makeSections())

            // If the phone already has a channel open, reflect it here.
            reconcileNowPlaying()
        }
    }

    func detach() {
        interfaceController = nil
    }

    // MARK: - Templates

    /// Channels grouped into sections by their playlist group.
    private func makeSections() -> [CPListSection] {
        let grouped = Dictionary(grouping: playback.channels) { $0.group ?? "Channels" }
        return grouped.keys.sorted().map { groupName -> CPListSection in
            let items = (grouped[groupName] ?? []).map(makeListItem)
            return CPListSection(items: items, header: groupName, sectionIndexTitle: nil)
        }
    }

    /// Uniform footprint for every list icon, so logos of different sizes and
    /// aspect ratios line up neatly.
    private let iconSize = CGSize(width: 88, height: 88)

    private func makeListItem(for channel: Channel) -> CPListItem {
        // Prefer the programme on air now; fall back to the channel's group.
        let detailText = EPGStore.shared.currentProgramme(for: channel)?.title ?? channel.group
        let item = CPListItem(text: channel.name, detailText: detailText)
        // Show the app logo immediately, then swap in the channel logo once loaded.
        item.setImage(UIImage(named: "LimeLogo")?.channelTile(size: iconSize))
        if let logoURL = channel.logoURL {
            Task {
                if let image = await ChannelLogoLoader.shared.image(for: logoURL) {
                    item.setImage(image.channelTile(size: self.iconSize))
                }
            }
        }
        item.handler = { _, completion in
            // Route through the shared path; the observer below reconciles both
            // the phone player and the CarPlay Now Playing screen.
            AppRouter.shared.openChannel(channel)
            completion()
        }
        return item
    }

    // MARK: - Navigation sync

    /// Observes the shared navigation path and mirrors it onto the CarPlay stack,
    /// so opening/closing a channel on the phone pushes/pops Now Playing here too
    /// (and vice versa, since a CarPlay tap sets the same path).
    private func observeRouter() {
        withObservationTracking {
            _ = AppRouter.shared.path
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.interfaceController != nil else { return }
                self.reconcileNowPlaying()
                self.observeRouter()
            }
        }
    }

    private func reconcileNowPlaying() {
        guard let interfaceController else { return }
        let selectedChannel = AppRouter.shared.path.last
        let nowPlayingOnTop = interfaceController.topTemplate === CPNowPlayingTemplate.shared

        if let channel = selectedChannel {
            if playback.currentChannel?.id != channel.id {
                playback.play(channel)
            }
            if !nowPlayingOnTop {
                interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true) { [log] success, error in
                    log.log("pushTemplate NowPlaying success=\(success) error=\(String(describing: error))")
                }
            }
        } else if nowPlayingOnTop {
            interfaceController.popTemplate(animated: true) { [log] success, error in
                log.log("popTemplate NowPlaying success=\(success) error=\(String(describing: error))")
            }
        }
    }
}

extension CarPlayCoordinator: CPInterfaceControllerDelegate {
    /// When the Now Playing template is popped (back on CarPlay), pop the phone
    /// app's player too so the two stay in sync.
    nonisolated func templateDidDisappear(_ aTemplate: CPTemplate, animated: Bool) {
        MainActor.assumeIsolated {
            guard aTemplate === CPNowPlayingTemplate.shared else { return }
            AppRouter.shared.path.removeAll()
        }
    }
}
