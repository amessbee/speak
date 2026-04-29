import SwiftUI
import AVKit
import AVFoundation

struct VideoSlideView: NSViewRepresentable {
    let url: URL
    var restartToken: UUID
    var onFinished: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let player = AVPlayer(url: url)
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        context.coordinator.attach(player: player)
        player.play()
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if context.coordinator.lastRestartToken != restartToken {
            context.coordinator.lastRestartToken = restartToken
            context.coordinator.restart()
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        var onFinished: () -> Void
        var lastRestartToken: UUID = UUID()
        private var player: AVPlayer?
        private var observer: NSObjectProtocol?

        init(onFinished: @escaping () -> Void) {
            self.onFinished = onFinished
        }

        func attach(player: AVPlayer) {
            self.player = player
            observer = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak self] _ in self?.onFinished() }
        }

        func restart() {
            player?.seek(to: .zero) { [weak self] _ in self?.player?.play() }
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            player?.pause()
        }
    }
}
