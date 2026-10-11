import CoreGraphics
import Testing
@testable import Mujo

@Suite("Onboarding motion policy")
struct OnboardingMotionPolicyTests {
    @Test("Ordinary onboarding steps use the calm vertical transition")
    func ordinaryStepsUseStandardMotion() {
        #expect(
            OnboardingMotionPolicy.style(
                from: .insights,
                to: .chooseLimit,
                reduceMotion: false
            ) == .standard
        )
        #expect(
            OnboardingMotionPolicy.style(
                from: .chooseLimit,
                to: .limitReached,
                reduceMotion: false
            ) == .standard
        )
        #expect(
            OnboardingMotionPolicy.style(
                from: .savings,
                to: .limitReached,
                reduceMotion: false
            ) == .standard
        )
        #expect(
            OnboardingMotionPolicy.style(
                from: .lockScreenWidget,
                to: .homeScreenWidget,
                reduceMotion: false
            ) == .standard
        )
    }

    @Test("Setting a limit keeps the selected time in the transition")
    func limitConfirmationUsesSharedValue() {
        #expect(
            OnboardingMotionPolicy.style(
                from: .chooseLimit,
                to: .savings,
                reduceMotion: false
            ) == .limitConfirmation
        )
    }

    @Test("Finishing onboarding reveals Home with sakura")
    func completionUsesSakura() {
        #expect(
            OnboardingMotionPolicy.style(
                from: .homeScreenWidget,
                to: nil,
                reduceMotion: false
            ) == .sakuraCompletion
        )
    }

    @Test("Inactive sakura reveal keeps the onboarding mask fully open")
    func inactiveCompletionKeepsMaskOpen() {
        #expect(OnboardingCompletionMaskPolicy.progress(
            showsCompletionPetals: false,
            transitionProgress: 0.8
        ) == 0)
        #expect(OnboardingCompletionMaskPolicy.progress(
            showsCompletionPetals: true,
            transitionProgress: 0.8
        ) == 0.8)
    }

    @Test("Lock Screen mockup follows the step with a delayed slide from above")
    func lockScreenMockupUsesDelayedSlide() {
        #expect(
            OnboardingMotionPolicy.lockScreenMockupStyle(
                reduceMotion: false
            ) == .delayedSlideFromTop
        )
    }

    @Test("Reduce Motion keeps the Lock Screen mockup in the step crossfade")
    func reduceMotionDisablesDelayedMockupSlide() {
        #expect(
            OnboardingMotionPolicy.lockScreenMockupStyle(
                reduceMotion: true
            ) == .crossfade
        )
    }

    @Test("Lock Screen extends only its mockup into the top safe area")
    func lockScreenKeepsStepGeometryStable() {
        let layout = OnboardingLockScreenLayout(
            containerWidth: 390,
            safeAreaTopInset: 59,
            globalMinY: 0
        )

        #expect(layout.previewHeight == 325)
        #expect(layout.contentTopInset == 59)
        #expect(layout.previewTopOffset == 0)
        #expect(layout.contentPlaceholderHeight == 266)

        let safeAreaConstrainedLayout = OnboardingLockScreenLayout(
            containerWidth: 390,
            safeAreaTopInset: 0,
            globalMinY: 59
        )

        #expect(safeAreaConstrainedLayout.contentTopInset == 59)
        #expect(safeAreaConstrainedLayout.previewTopOffset == -59)
        #expect(safeAreaConstrainedLayout.contentPlaceholderHeight == 266)
    }

    @Test("Savings card stays visible while shrinking upward on exit")
    func savingsCardHasDistinctExitMotion() {
        let start = OnboardingSavingsCardExitMotion.sample(at: 0)
        let middle = OnboardingSavingsCardExitMotion.sample(at: 0.5)
        let end = OnboardingSavingsCardExitMotion.sample(at: 1)

        #expect(start.scale == 1)
        #expect(start.verticalOffset == 0)
        #expect(start.opacity == 1)
        #expect(middle.scale < start.scale)
        #expect(middle.verticalOffset < start.verticalOffset)
        #expect(middle.opacity > 0.5)
        #expect(end.scale < middle.scale)
        #expect(end.verticalOffset < middle.verticalOffset)
        #expect(end.opacity == 0)
    }

    @Test("Sakura petals are visible between their hidden endpoints")
    func sakuraPetalHasVisibleMidflightState() {
        let motion = OnboardingSakuraPetalMotion(
            delay: 0,
            baseY: 120,
            wavePhase: 0,
            waveAmplitude: 24,
            verticalDrift: 26
        )

        let start = motion.sample(
            at: 0,
            canvasWidth: 300,
            petalSize: 20
        )
        let middle = motion.sample(
            at: 0.5,
            canvasWidth: 300,
            petalSize: 20
        )
        let end = motion.sample(
            at: 1,
            canvasWidth: 300,
            petalSize: 20
        )

        #expect(start.opacity == 0)
        #expect(middle.opacity > 0.9)
        #expect(end.opacity == 0)
        #expect(start.position.x > middle.position.x)
        #expect(middle.position.x > end.position.x)
    }

    @Test("Sakura gust masks the screen when Home is revealed")
    func sakuraGustCoversScreenAtHomeReveal() {
        let canvasSize = CGSize(width: 390, height: 844)
        let samples = OnboardingSakuraGust.petals(in: canvasSize).map {
            $0.motion.sample(
                at: OnboardingSakuraGust.homeRevealProgress,
                canvasWidth: canvasSize.width,
                petalSize: $0.size
            )
        }
        let visibleSamples = samples.filter { $0.opacity > 0.8 }

        #expect(visibleSamples.count >= 60)
        #expect(visibleSamples.contains { $0.position.x < 130 })
        #expect(visibleSamples.contains {
            $0.position.x >= 130 && $0.position.x < 260
        })
        #expect(visibleSamples.contains { $0.position.x >= 260 })
    }

    @Test("Sakura gust reveals Home continuously from right to left")
    func sakuraGustUsesDirectionalReveal() {
        let width: CGFloat = 390
        let start = OnboardingSakuraWipe.visibleOnboardingWidth(
            at: 0,
            canvasWidth: width
        )
        let quarter = OnboardingSakuraWipe.visibleOnboardingWidth(
            at: 0.25,
            canvasWidth: width
        )
        let middle = OnboardingSakuraWipe.visibleOnboardingWidth(
            at: 0.5,
            canvasWidth: width
        )
        let end = OnboardingSakuraWipe.visibleOnboardingWidth(
            at: 1,
            canvasWidth: width
        )

        #expect(start == width)
        #expect(quarter < start)
        #expect(quarter > middle)
        #expect(middle > 130 && middle < 260)
        #expect(end == 0)
    }

    @Test("Limit hero travels from the selected value to its confirmation slot")
    func limitHeroInterpolatesBetweenMeasuredFrames() {
        let motion = OnboardingLimitHeroMotion(
            sourceFrame: CGRect(x: 50, y: 100, width: 200, height: 100),
            destinationFrame: CGRect(x: 200, y: 300, width: 80, height: 20),
            sourceFontSize: 88,
            destinationFontSize: 20
        )

        let start = motion.sample(at: 0)
        let middle = motion.sample(at: 0.5)
        let end = motion.sample(at: 1)

        #expect(start.position == CGPoint(x: 150, y: 150))
        #expect(middle.position == CGPoint(x: 195, y: 230))
        #expect(end.position == CGPoint(x: 240, y: 310))
        #expect(start.fontSize == 88)
        #expect(middle.fontSize == 54)
        #expect(end.fontSize == 20)
    }

    @Test("Reduce Motion replaces every transition with a crossfade")
    func reduceMotionUsesCrossfade() {
        let transitions: [(OnboardingStep, OnboardingStep?)] = [
            (.insights, .chooseLimit),
            (.chooseLimit, .savings),
            (.chooseLimit, .limitReached),
            (.savings, .limitReached),
            (.limitReached, .notifications),
            (.notifications, .lockScreenWidget),
            (.lockScreenWidget, .homeScreenWidget),
            (.homeScreenWidget, nil)
        ]

        for (source, destination) in transitions {
            #expect(
                OnboardingMotionPolicy.style(
                    from: source,
                    to: destination,
                    reduceMotion: true
                ) == .crossfade
            )
        }
    }
}
