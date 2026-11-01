import AVFoundation
import Combine
import SwiftUI
import UIKit

enum OnboardingIntroductionVideoHoldMode: Equatable {
    case fastForward
    case pause
}

enum OnboardingIntroductionVideoPolicy {
    static let frameRate = 30.0
    static let durationInFrames = 1514
    static let textStartFrames = [
        0, 116, 186, 292, 349, 406, 463, 575,
        674, 748, 834, 946, 1032, 1184, 1290, 1392
    ]
    static let cherryBlossomProgress = 186.0 / 1514.0

    static func holdMode(atX x: CGFloat, width: CGFloat) -> OnboardingIntroductionVideoHoldMode {
        guard width.isFinite, width > 0, x.isFinite, (0...width).contains(x) else {
            return .pause
        }
        return x < width * 0.25 || x > width * 0.75 ? .fastForward : .pause
    }

    static func nextTextTime(after currentTime: TimeInterval) -> TimeInterval? {
        guard currentTime.isFinite else { return nil }
        let currentFrame = Int(floor(max(0, currentTime) * frameRate))
        guard let nextStart = textStartFrames.first(where: { $0 > currentFrame }) else {
            return nil
        }
        return Double(nextStart + 9) / frameRate
    }

    static func resourceName(for colorScheme: ColorScheme) -> String {
        switch colorScheme {
        case .dark:
            "mujo_onboarding_dark"
        case .light:
            "mujo_onboarding_light"
        @unknown default:
            "mujo_onboarding_light"
        }
    }

    static func progress(
        currentTime: TimeInterval,
        duration: TimeInterval
    ) -> Double {
        guard currentTime.isFinite, duration.isFinite, duration > 0 else {
            return 0
        }
        return min(1, max(0, currentTime / duration))
    }

    static func finalFrameTime(duration: TimeInterval) -> TimeInterval {
        max(0, duration - (1 / frameRate))
    }
}

@MainActor
final class OnboardingIntroductionVideoPlayback: ObservableObject {
    let player = AVPlayer()
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var progress = 0.0
    @Published private(set) var isFinished = false

    private var currentResourceName: String?
    private var endObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var isActive = true
    private var holdMode: OnboardingIntroductionVideoHoldMode?

    func start(resourceName: String) {
        guard currentResourceName == nil else {
            updateResource(resourceName)
            return
        }
        install(resourceName: resourceName, preserving: 0, finished: false)
    }

    func updateResource(_ resourceName: String) {
        guard resourceName != currentResourceName else { return }
        let preservedTime = player.currentTime().seconds
        install(
            resourceName: resourceName,
            preserving: preservedTime.isFinite ? max(0, preservedTime) : 0,
            finished: isFinished
        )
    }

    func setActive(_ isActive: Bool) {
        self.isActive = isActive
        if !isActive { holdMode = nil }
        applyPlaybackRate()
    }

    func setHoldMode(_ holdMode: OnboardingIntroductionVideoHoldMode?) {
        self.holdMode = holdMode
        applyPlaybackRate()
    }

    func skipToNextText() async {
        guard !isFinished, let item = player.currentItem else { return }
        let playerTime = player.currentTime().seconds
        let currentTime = playerTime.isFinite
            ? max(elapsedTime, playerTime) : elapsedTime
        guard let targetSeconds = OnboardingIntroductionVideoPolicy
            .nextTextTime(after: currentTime) else {
            await finishAndHoldFinalFrame(of: item)
            return
        }

        let didSeek = await player.seek(
            to: CMTime(seconds: targetSeconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        guard didSeek, item === player.currentItem else { return }
        elapsedTime = targetSeconds
        progress = OnboardingIntroductionVideoPolicy.progress(
            currentTime: targetSeconds,
            duration: item.duration.seconds
        )
        applyPlaybackRate()
    }

    func stop() {
        player.pause()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        removeEndObserver()
        player.replaceCurrentItem(with: nil)
        currentResourceName = nil
        elapsedTime = 0
        progress = 0
        isFinished = false
        holdMode = nil
    }

    private func install(
        resourceName: String,
        preserving preservedTime: TimeInterval,
        finished: Bool
    ) {
        guard let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: "mp4"
        ) else {
            assertionFailure("Missing onboarding video: \(resourceName).mp4")
            return
        }

        removeEndObserver()
        currentResourceName = resourceName
        player.isMuted = true
        player.actionAtItemEnd = .pause

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self, weak item] _ in
            MainActor.assumeIsolated {
                guard let self, let item else { return }
                self.holdFinalFrame(of: item)
            }
        }

        if timeObserver == nil {
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 1 / 30, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                MainActor.assumeIsolated {
                    self?.updateProgress(at: time)
                }
            }
        }

        if !finished {
            elapsedTime = preservedTime
            isFinished = false
        }

        Task { [weak self, weak item] in
            guard let self, let item else { return }
            let duration = try? await item.asset.load(.duration).seconds
            guard item === self.player.currentItem else { return }
            let safeDuration = duration.flatMap { $0.isFinite ? $0 : nil } ?? 0
            let targetSeconds = finished
                ? OnboardingIntroductionVideoPolicy.finalFrameTime(
                    duration: safeDuration
                )
                : min(preservedTime, max(0, safeDuration))
            await self.player.seek(
                to: CMTime(seconds: targetSeconds, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
            guard item === self.player.currentItem else { return }

            if finished {
                self.player.pause()
                self.elapsedTime = safeDuration
                self.progress = 1
                self.isFinished = true
            } else {
                self.applyPlaybackRate()
            }
        }
    }

    private func updateProgress(at time: CMTime) {
        guard !isFinished else { return }
        let currentTime = time.seconds
        let duration = player.currentItem?.duration.seconds ?? 0
        elapsedTime = currentTime.isFinite ? max(0, currentTime) : 0
        progress = OnboardingIntroductionVideoPolicy.progress(
            currentTime: elapsedTime,
            duration: duration
        )
    }

    private func holdFinalFrame(of item: AVPlayerItem) {
        Task { [weak self, weak item] in
            guard let self, let item else { return }
            await self.finishAndHoldFinalFrame(of: item)
        }
    }

    private func finishAndHoldFinalFrame(of item: AVPlayerItem) async {
        guard item === player.currentItem, !isFinished else { return }
        player.pause()
        holdMode = nil

        let duration = try? await item.asset.load(.duration).seconds
        guard item === player.currentItem,
              let duration,
              duration.isFinite,
              duration > 0 else { return }
        let didSeek = await player.seek(
            to: CMTime(
                seconds: OnboardingIntroductionVideoPolicy.finalFrameTime(
                    duration: duration
                ),
                preferredTimescale: 600
            ),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        guard didSeek, item === player.currentItem else { return }
        elapsedTime = duration
        progress = 1
        isFinished = true
    }

    private func removeEndObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    private func applyPlaybackRate() {
        guard isActive, !isFinished, player.currentItem != nil, holdMode != .pause else {
            player.pause()
            return
        }
        player.play()
        player.rate = holdMode == .fastForward ? 2 : 1
    }
}

struct OnboardingIntroductionVideo: UIViewRepresentable {
    let player: AVPlayer
    let onTap: () -> Void
    let onHoldModeChanged: (OnboardingIntroductionVideoHoldMode?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTap: onTap,
            onHoldModeChanged: onHoldModeChanged
        )
    }

    func makeUIView(context: Context) -> VideoSurface {
        let view = VideoSurface()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        view.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.didTap)
        )
        let hold = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.didHold)
        )
        hold.minimumPressDuration = 0.3
        tap.require(toFail: hold)
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(hold)
        return view
    }

    func updateUIView(_ uiView: VideoSurface, context: Context) {
        uiView.playerLayer.player = player
        context.coordinator.onTap = onTap
        context.coordinator.onHoldModeChanged = onHoldModeChanged
    }

    static func dismantleUIView(_ uiView: VideoSurface, coordinator: Coordinator) {
        uiView.playerLayer.player = nil
        coordinator.onHoldModeChanged(nil)
    }

    final class Coordinator: NSObject {
        var onTap: () -> Void
        var onHoldModeChanged: (OnboardingIntroductionVideoHoldMode?) -> Void

        init(
            onTap: @escaping () -> Void,
            onHoldModeChanged: @escaping (OnboardingIntroductionVideoHoldMode?) -> Void
        ) {
            self.onTap = onTap
            self.onHoldModeChanged = onHoldModeChanged
        }

        @objc func didTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else { return }
            onTap()
        }

        @objc func didHold(_ gesture: UILongPressGestureRecognizer) {
            switch gesture.state {
            case .began:
                guard let view = gesture.view else { return }
                onHoldModeChanged(
                    OnboardingIntroductionVideoPolicy.holdMode(
                        atX: gesture.location(in: view).x,
                        width: view.bounds.width
                    )
                )
            case .ended, .cancelled, .failed:
                onHoldModeChanged(nil)
            default:
                break
            }
        }
    }

    final class VideoSurface: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
