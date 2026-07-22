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
final class CarPlayCoordinator {
    private let playback = PlaybackController.shared
    private var interfaceController: CPInterfaceController?
    private let listTemplate = CPListTemplate(title: "LimesTV", sections: [])
    private let log = Logger(subsystem: "com.lymes.LimesTV", category: "CarPlay")

    /// Called when the CarPlay screen connects. Sets the root template
    /// synchronously so CarPlay always has content, then fills in the channels.
    func attach(to interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        log.log("CarPlay didConnect")

        // Set the root template immediately: CarPlay shows a blank screen if the
        // root isn't set promptly, so we can't wait for the async channel load.
        listTemplate.updateSections(makeSections())
        interfaceController.setRootTemplate(listTemplate, animated: false) { [log] success, error in
            log.log("setRootTemplate success=\(success) error=\(String(describing: error))")
        }

        Task {
            await playback.loadChannelsIfNeeded()
            log.log("Loaded \(self.playback.channels.count) channels")
            listTemplate.updateSections(makeSections())
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
        let item = CPListItem(text: channel.name, detailText: channel.group)
        // Show the app logo immediately, then swap in the channel logo once loaded.
        item.setImage(UIImage(named: "LimeLogo")?.channelTile(size: iconSize))
        if let logoURL = channel.logoURL {
            Task {
                if let image = await ChannelLogoLoader.shared.image(for: logoURL) {
                    item.setImage(image.channelTile(size: self.iconSize))
                }
            }
        }
        item.handler = { [weak self] _, completion in
            guard let self else { completion(); return }
            self.playback.play(channel)
            self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true) { [log = self.log] success, error in
                log.log("pushTemplate NowPlaying success=\(success) error=\(String(describing: error))")
            }
            completion()
        }
        return item
    }
}
