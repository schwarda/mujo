import AVFoundation
import SwiftUI
import Testing
import UIKit
@testable import Mujo

@MainActor
@Suite("Widget video tutorials")
struct OnboardingWidgetTutorialTests {
    @Test("Each cue switches at its video time and a loop returns to step one")
    func followsPlaybackTime() {
        for help in [OnboardingWidgetHelp.homeScreen, .lockScreen] {
            #expect(help.stepStartTimes.count == help.steps.count)
            #expect(help.stepIndex(at: 0) == 0)
            for index in 1..<help.stepStartTimes.count {
                let cue = help.stepStartTimes[index]
                #expect(help.stepIndex(at: cue - 0.01) == index - 1)
                #expect(help.stepIndex(at: cue) == index)
            }
            #expect(help.stepIndex(at: 100) == help.steps.count - 1)
            #expect(help.stepIndex(at: 0) == 0)
        }
    }

    @Test("Both bundled videos open muted and closing removes the playback queue")
    func opensAndClosesBothTutorials() async throws {
        for help in [OnboardingWidgetHelp.homeScreen, .lockScreen] {
            let playback = OnboardingWidgetTutorialPlayback()
            playback.start(resourceName: help.videoResourceName)
            #expect(playback.player.isMuted)
            #expect(playback.elapsedTime == 0)
            _ = try await readyItem(in: playback)

            playback.stop()
            #expect(playback.player.currentItem == nil)
            #expect(playback.player.items().isEmpty)
            #expect(playback.player.rate == 0)
            #expect(playback.elapsedTime == 0)
        }
    }

    @Test("Reopening replaces the old video item with a session at zero")
    func reopensFromBeginning() async throws {
        let playback = OnboardingWidgetTutorialPlayback()
        playback.start(resourceName: OnboardingWidgetHelp.homeScreen.videoResourceName)
        playback.setActive(false)
        _ = try await readyItem(in: playback)
        let didSeek = await playback.player.seek(
            to: CMTime(seconds: 6, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        #expect(didSeek)
        #expect(abs(playback.player.currentTime().seconds - 6) < 0.1)
        let previousItem = playback.player.currentItem
        playback.stop()

        playback.start(resourceName: OnboardingWidgetHelp.homeScreen.videoResourceName)
        playback.setActive(false)
        _ = try await readyItem(in: playback)
        #expect(playback.player.currentItem !== previousItem)
        #expect(playback.player.currentTime().seconds == 0)
        #expect(playback.elapsedTime == 0)
        playback.stop()
    }

    @Test("The real video clock wraps to the first step after the video ends")
    func loopsVideoAndCues() async throws {
        for help in [OnboardingWidgetHelp.homeScreen, .lockScreen] {
            let playback = OnboardingWidgetTutorialPlayback()
            playback.start(resourceName: help.videoResourceName)
            defer { playback.stop() }
            playback.setActive(false)
            let item = try await readyItem(in: playback)
            let duration = try await item.asset.load(.duration).seconds
            #expect(try #require(help.stepStartTimes.last) < duration)
            let didSeek = await playback.player.seek(
                to: CMTime(seconds: duration - 0.6, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
            #expect(didSeek)
            playback.setActive(true)

            var sawLastStep = false
            var sawLoop = false
            for _ in 0..<50 {
                try await Task.sleep(for: .milliseconds(100))
                if help.stepIndex(at: playback.elapsedTime) == help.steps.count - 1 {
                    sawLastStep = true
                }
                if sawLastStep && playback.elapsedTime < 1 {
                    sawLoop = true
                    break
                }
            }
            #expect(sawLastStep)
            #expect(sawLoop)
            #expect(help.stepIndex(at: playback.elapsedTime) == 0)
        }
    }

    @Test("Changing the tutorial in an existing view switches the displayed video")
    func changesVideoWhenHelpChanges() async throws {
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: OnboardingWidgetHelpSheet(help: .lockScreen))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }

        var displayedPlayer: AVPlayer?
        for _ in 0..<50 {
            displayedPlayer = videoPlayer(in: host.view.layer)
            if displayedPlayer?.currentItem?.status == .readyToPlay { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let player = try #require(displayedPlayer)
        #expect((player.currentItem?.asset as? AVURLAsset)?.url.lastPathComponent == "lock_screen.mp4")

        // SwiftUI can keep the view and its StateObject when the input changes,
        // including when switching Canvas previews of the same view type.
        for help in [OnboardingWidgetHelp.homeScreen, .lockScreen] {
            host.rootView = OnboardingWidgetHelpSheet(help: help)
            let expectedFile = "\(help.videoResourceName).mp4"
            for _ in 0..<30 {
                if (player.currentItem?.asset as? AVURLAsset)?.url.lastPathComponent == expectedFile {
                    break
                }
                try await Task.sleep(for: .milliseconds(100))
            }
            #expect((player.currentItem?.asset as? AVURLAsset)?.url.lastPathComponent == expectedFile)
        }
    }

    private func videoPlayer(in layer: CALayer) -> AVPlayer? {
        if let playerLayer = layer as? AVPlayerLayer { return playerLayer.player }
        for child in layer.sublayers ?? [] {
            if let player = videoPlayer(in: child) { return player }
        }
        return nil
    }

    private func readyItem(
        in playback: OnboardingWidgetTutorialPlayback
    ) async throws -> AVPlayerItem {
        for _ in 0..<100 {
            if let item = playback.player.currentItem, item.status == .readyToPlay {
                return item
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        let item = try #require(playback.player.currentItem)
        try #require(item.status == .readyToPlay, "Video did not become ready: \(String(describing: item.error))")
        return item
    }
}
