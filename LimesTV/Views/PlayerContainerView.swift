//
//  PlayerContainerView.swift
//  LimesTV
//
//  Wraps AVPlayerViewController so playback supports Picture in Picture, which
//  SwiftUI's VideoPlayer doesn't expose. PiP starts automatically when the app
//  is backgrounded while a channel is playing.
//

import AVKit
import SwiftUI

struct PlayerContainerView: UIViewControllerRepresentable {
    let player: AVPlayer?

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.videoGravity = .resizeAspect
        // Now Playing is managed by PlaybackController, so don't let the
        // controller overwrite it.
        controller.updatesNowPlayingInfoCenter = false
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}
