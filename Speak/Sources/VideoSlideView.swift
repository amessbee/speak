import SwiftUI
import AVKit
import AVFoundation

/// Plays a video using AVKit's AVPlayerView.
/// Calls `onFinished` when playback ends so the sequence can auto-advance.
struct VideoSlideView: NSViewRepresentable {
    let url: URL
    var onFinished: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let player = AVPlayer(url: url)
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none       // Hide controls for seamless presentation
        view.videoGravity = .resizeAspect

        // Observe end of playback
        context.coordinator.observe(player: player)
        player.play()

        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        // No-op: player is set up once in makeNSView
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        var onFinished: () -> Void
        private var observer: NSObjectProtocol?
        private var player: AVPlayer?

        init(onFinished: @escaping () -> Void) {
            self.onFinished = onFinished
        }

        func observe(player: AVPlayer) {
            self.player = player
            observer = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak self] _ in
                self?.onFinished()
            }
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            player?.pause()
        }
    }
}
