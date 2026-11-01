import AVFoundation
import Combine
import SwiftUI
import UIKit

/// A sheet owns one session; every presentation creates a fresh looping queue.
@MainActor
final class OnboardingWidgetTutorialPlayback: ObservableObject {
    let player = AVQueuePlayer()
    @Published private(set) var elapsedTime: TimeInterval = 0

    private var looper: AVPlayerLooper?
    private var timeObserver: Any?

    func start(resourceName: String) {
        stop()
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "mp4") else {
            assertionFailure("Missing widget tutorial video: \(resourceName)")
            return
        }

        player.isMuted = true
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            // AVPlayer invokes this callback on the explicitly selected main queue.
            MainActor.assumeIsolated {
                guard let self, self.looper != nil else { return }
                self.elapsedTime = time.seconds.isFinite ? max(0, time.seconds) : 0
            }
        }
        player.play()
    }

    func setActive(_ isActive: Bool) {
        guard looper != nil else { return }
        if isActive {
            player.play()
        } else {
            player.pause()
        }
    }

    func stop() {
        player.pause()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
        elapsedTime = 0
    }
}

/// An AVPlayerLayer provides video pixels without any player controls or gestures.
struct OnboardingWidgetTutorialVideo: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> VideoSurface {
        let view = VideoSurface()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: VideoSurface, context: Context) {
        uiView.playerLayer.player = player
    }

    static func dismantleUIView(_ uiView: VideoSurface, coordinator: ()) {
        uiView.playerLayer.player = nil
    }

    final class VideoSurface: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
