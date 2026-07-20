//
//  CarPlayCoordinator.swift
//  LimesTV
//
//  Builds the CarPlay channel list and drives playback through the shared
//  PlaybackController. Acts as the "view model" for the CarPlay scene.
//

import CarPlay

@MainActor
final class CarPlayCoordinator {
    private let playback = PlaybackController.shared
    private var interfaceController: CPInterfaceController?

    /// Called when the CarPlay screen connects: loads channels and shows the list.
    func attach(to interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        Task {
            await playback.loadChannelsIfNeeded()
            let template = makeChannelListTemplate()
            interfaceController.setRootTemplate(template, animated: true, completion: nil)
        }
    }

    func detach() {
        interfaceController = nil
    }

    // MARK: - Templates

    /// A list of channels grouped into sections by their playlist group.
    private func makeChannelListTemplate() -> CPListTemplate {
        let grouped = Dictionary(grouping: playback.channels) { $0.group ?? "Channels" }
        let sections = grouped.keys.sorted().map { groupName -> CPListSection in
            let items = (grouped[groupName] ?? []).map(makeListItem)
            return CPListSection(items: items, header: groupName, sectionIndexTitle: nil)
        }
        return CPListTemplate(title: "LimesTV", sections: sections)
    }

    private func makeListItem(for channel: Channel) -> CPListItem {
        let item = CPListItem(text: channel.name, detailText: channel.group)
        item.handler = { [weak self] _, completion in
            guard let self else { completion(); return }
            self.playback.play(channel)
            self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            completion()
        }
        return item
    }
}
