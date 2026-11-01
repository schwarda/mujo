import AVFoundation
import SwiftUI
import Testing
@testable import Mujo

@MainActor
@Suite("Introduction video")
struct OnboardingIntroductionVideoTests {
    @Test("Both silent onboarding renders are bundled with the approved timing")
    func bundledVideosMatchApprovedMetadata() async throws {
        for resourceName in ["mujo_onboarding_light", "mujo_onboarding_dark"] {
            let url = try #require(
                Bundle.main.url(forResource: resourceName, withExtension: "mp4"),
                "Missing bundled onboarding video: \(resourceName).mp4"
            )
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration).seconds
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)

            #expect(abs(duration - (1514.0 / 30.0)) < 0.02)
            #expect(videoTracks.count == 1)
            #expect(audioTracks.isEmpty)
        }
    }

    @Test("The system appearance selects the matching render")
    func selectsRenderForColorScheme() {
        #expect(
            OnboardingIntroductionVideoPolicy.resourceName(for: .light)
                == "mujo_onboarding_light"
        )
        #expect(
            OnboardingIntroductionVideoPolicy.resourceName(for: .dark)
                == "mujo_onboarding_dark"
        )
    }

    @Test("Progress and the held frame are derived from real playback time")
    func derivesProgressAndFinalFrameTime() {
        #expect(
            OnboardingIntroductionVideoPolicy.cherryBlossomProgress
                == 186.0 / 1514.0
        )
        #expect(
            OnboardingIntroductionVideoPolicy.progress(
                currentTime: 23.0,
                duration: 46.0
            ) == 0.5
        )
        #expect(
            OnboardingIntroductionVideoPolicy.progress(
                currentTime: 60.0,
                duration: 46.0
            ) == 1
        )
        #expect(
            OnboardingIntroductionVideoPolicy.finalFrameTime(duration: 10)
                == 10 - (1.0 / 30.0)
        )
    }

    @Test("A tap seeks to fully visible next copy, then advances one cue at a time")
    func skipsToNextVisibleText() async throws {
        let playback = OnboardingIntroductionVideoPlayback()
        playback.start(resourceName: "mujo_onboarding_light")
        defer { playback.stop() }
        _ = try await readyItem(in: playback)
        playback.setActive(false)

        await playback.skipToNextText()
        #expect(abs(playback.player.currentTime().seconds - (125.0 / 30.0)) < 0.05)

        await playback.skipToNextText()
        #expect(abs(playback.player.currentTime().seconds - (195.0 / 30.0)) < 0.05)

        #expect(OnboardingIntroductionVideoPolicy.nextTextTime(after: 1400.0 / 30.0) == nil)
    }

    @Test("A tap on the final message reveals Continue and holds its final frame")
    func finalMessageTapFinishesIntroduction() async throws {
        let playback = OnboardingIntroductionVideoPlayback()
        playback.start(resourceName: "mujo_onboarding_light")
        defer { playback.stop() }
        let item = try await readyItem(in: playback)
        playback.setActive(false)
        let duration = try await item.asset.load(.duration).seconds

        let didSeek = await playback.player.seek(
            to: CMTime(seconds: 1390.0 / 30.0, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        #expect(didSeek)

        await playback.skipToNextText()
        #expect(!playback.isFinished)
        #expect(abs(playback.player.currentTime().seconds - (1401.0 / 30.0)) < 0.05)

        await playback.skipToNextText()
        #expect(playback.isFinished)
        #expect(playback.progress == 1)
        #expect(playback.player.rate == 0)
        #expect(
            abs(playback.player.currentTime().seconds
                - OnboardingIntroductionVideoPolicy.finalFrameTime(duration: duration)) < 0.05
        )
    }

    @Test("Only the side quarters fast-forward; holding elsewhere pauses")
    func holdZonesMatchReelsStyle() {
        let mode = OnboardingIntroductionVideoPolicy.holdMode(atX: 0, width: 100)
        #expect(mode == .fastForward)
        #expect(OnboardingIntroductionVideoPolicy.holdMode(atX: 24, width: 100) == .fastForward)
        #expect(OnboardingIntroductionVideoPolicy.holdMode(atX: 25, width: 100) == .pause)
        #expect(OnboardingIntroductionVideoPolicy.holdMode(atX: 50, width: 100) == .pause)
        #expect(OnboardingIntroductionVideoPolicy.holdMode(atX: 75, width: 100) == .pause)
        #expect(OnboardingIntroductionVideoPolicy.holdMode(atX: 76, width: 100) == .fastForward)
        #expect(OnboardingIntroductionVideoPolicy.holdMode(atX: 100, width: 100) == .fastForward)
    }

    @Test("Holding a side doubles speed, holding the middle pauses, and release resumes")
    func holdModesControlPlaybackOnlyWhileHeld() async throws {
        let playback = OnboardingIntroductionVideoPlayback()
        playback.start(resourceName: "mujo_onboarding_light")
        defer { playback.stop() }
        _ = try await readyItem(in: playback)

        playback.setActive(true)
        playback.setHoldMode(.fastForward)
        #expect(playback.player.rate == 2)

        playback.setHoldMode(.pause)
        #expect(playback.player.rate == 0)

        playback.setHoldMode(nil)
        #expect(playback.player.rate == 1)

        playback.setActive(false)
        #expect(playback.player.rate == 0)
    }

    @Test("Playback stops on and keeps the privacy frame")
    func holdsPrivacyFrameAtTheEnd() async throws {
        let playback = OnboardingIntroductionVideoPlayback()
        playback.start(resourceName: "mujo_onboarding_light")
        defer { playback.stop() }
        let item = try await readyItem(in: playback)
        let duration = try await item.asset.load(.duration).seconds

        let didSeek = await playback.player.seek(
            to: CMTime(
                seconds: duration - 0.25,
                preferredTimescale: 600
            ),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        #expect(didSeek)
        playback.setActive(true)

        for _ in 0..<40 where !playback.isFinished {
            try await Task.sleep(for: .milliseconds(100))
        }

        #expect(playback.isFinished)
        #expect(playback.progress == 1)
        #expect(playback.player.rate == 0)
        #expect(
            abs(
                playback.player.currentTime().seconds
                    - OnboardingIntroductionVideoPolicy.finalFrameTime(
                        duration: duration
                    )
            ) < 0.05
        )
    }

    @Test("Changing appearance swaps the render without restarting playback")
    func changesRenderAtTheSamePlaybackTime() async throws {
        let playback = OnboardingIntroductionVideoPlayback()
        playback.start(resourceName: "mujo_onboarding_light")
        defer { playback.stop() }
        _ = try await readyItem(in: playback)
        playback.setActive(false)

        let didSeek = await playback.player.seek(
            to: CMTime(seconds: 12, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        #expect(didSeek)
        playback.updateResource("mujo_onboarding_dark")

        for _ in 0..<100 {
            let fileName = (playback.player.currentItem?.asset as? AVURLAsset)?
                .url.lastPathComponent
            let currentTime = playback.player.currentTime().seconds
            if fileName == "mujo_onboarding_dark.mp4",
                abs(currentTime - 12) < 0.05 {
                break
            }
            try await Task.sleep(for: .milliseconds(50))
        }

        let fileName = (playback.player.currentItem?.asset as? AVURLAsset)?
            .url.lastPathComponent
        #expect(fileName == "mujo_onboarding_dark.mp4")
        #expect(abs(playback.player.currentTime().seconds - 12) < 0.05)
        #expect(playback.player.rate == 0)
    }

    private func readyItem(
        in playback: OnboardingIntroductionVideoPlayback
    ) async throws -> AVPlayerItem {
        for _ in 0..<100 {
            if let item = playback.player.currentItem,
                item.status == .readyToPlay {
                return item
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        let item = try #require(playback.player.currentItem)
        try #require(
            item.status == .readyToPlay,
            "Video did not become ready: \(String(describing: item.error))"
        )
        return item
    }
}
