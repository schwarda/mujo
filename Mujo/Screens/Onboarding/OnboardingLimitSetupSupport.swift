import SwiftUI

enum OnboardingStep: Hashable {
    case insights
    case chooseLimit
    case savings
    case limitReached
    case notifications
    case lockScreenWidget
    case homeScreenWidget
}

enum OnboardingMotionStyle: Equatable {
    case standard
    case limitConfirmation
    case sakuraCompletion
    case crossfade
}

enum OnboardingElementMotionStyle: Equatable {
    case delayedSlideFromTop
    case crossfade
}

enum OnboardingMotionPolicy {
    static func style(
        from source: OnboardingStep,
        to destination: OnboardingStep?,
        reduceMotion: Bool
    ) -> OnboardingMotionStyle {
        if reduceMotion {
            return .crossfade
        }
        if source == .chooseLimit, destination == .savings {
            return .limitConfirmation
        }
        if source == .homeScreenWidget, destination == nil {
            return .sakuraCompletion
        }
        return .standard
    }

    static func lockScreenMockupStyle(
        reduceMotion: Bool
    ) -> OnboardingElementMotionStyle {
        reduceMotion ? .crossfade : .delayedSlideFromTop
    }
}

enum OnboardingInteractionMetrics {
    static let stepAnimationDuration = 0.45
    static let limitConfirmationAnimationDuration = 0.55
    static let reducedMotionAnimationDuration = 0.2
    static let lockScreenMockupDelay = 0.74
    static let lockScreenMockupAnimationDuration = 0.62
    static let lockScreenMockupVerticalOffset: CGFloat = -36
    static let limitHeroAnimationDuration = 0.65
}

struct OnboardingSakuraPetalMotion {
    struct Sample {
        let position: CGPoint
        let rotationDegrees: Double
        let opacity: Double
    }

    let delay: Double
    let baseY: CGFloat
    let wavePhase: Double
    let waveAmplitude: CGFloat
    let verticalDrift: CGFloat
    let travelDuration: Double

    init(
        delay: Double,
        baseY: CGFloat,
        wavePhase: Double,
        waveAmplitude: CGFloat,
        verticalDrift: CGFloat,
        travelDuration: Double? = nil
    ) {
        self.delay = delay
        self.baseY = baseY
        self.wavePhase = wavePhase
        self.waveAmplitude = waveAmplitude
        self.verticalDrift = verticalDrift
        self.travelDuration = travelDuration ?? max(0.001, 1 - delay)
    }

    func sample(
        at progress: Double,
        canvasWidth: CGFloat,
        petalSize: CGFloat
    ) -> Sample {
        let clampedProgress = min(1, max(0, progress))
        let localProgress = min(
            1,
            max(0, (clampedProgress - delay) / travelDuration)
        )
        let startX = canvasWidth + petalSize
        let endX = -petalSize
        let x = startX + (endX - startX) * localProgress
        let wave = sin(localProgress * .pi * 2.4 + wavePhase)
            * waveAmplitude
        let y = baseY + wave + localProgress * verticalDrift
        let opacity = min(
            1,
            max(
                0,
                min(localProgress / 0.08, (1 - localProgress) / 0.12)
            )
        )

        return Sample(
            position: CGPoint(x: x, y: y),
            rotationDegrees: localProgress * 720,
            opacity: opacity * 0.96
        )
    }
}

enum OnboardingSakuraGust {
    struct Petal {
        let index: Int
        let size: CGFloat
        let rotationMultiplier: Double
        let motion: OnboardingSakuraPetalMotion
    }

    static let animationDuration = 5.2
    static let homeRevealProgress = 1_050 / (animationDuration * 1_000)

    static var animation: Animation {
        .timingCurve(0.32, 0, 0.22, 1, duration: animationDuration)
    }

    private static let petalCount = 76

    static func petals(in canvasSize: CGSize) -> [Petal] {
        (0..<petalCount).map { index in
            let travelDuration = 0.58 + random(index, salt: 7) * 0.24
            let delay = random(index, salt: 1) * (1 - travelDuration)

            return Petal(
                index: index,
                size: 26 + random(index, salt: 2) * 26,
                rotationMultiplier: 0.42 + random(index, salt: 6) * 0.52,
                motion: OnboardingSakuraPetalMotion(
                    delay: delay,
                    baseY: canvasSize.height
                        * (0.02 + random(index, salt: 3) * 0.96),
                    wavePhase: random(index, salt: 4) * .pi * 2,
                    waveAmplitude: 14 + random(index, salt: 5) * 32,
                    verticalDrift: -18 + random(index, salt: 8) * 54,
                    travelDuration: travelDuration
                )
            )
        }
    }

    private static func random(_ index: Int, salt: Int) -> Double {
        let value = sin(Double(index * 97 + salt * 53)) * 43_758.5453
        return value - floor(value)
    }
}

enum OnboardingSakuraWipe {
    static let softEdgeWidth: CGFloat = 72

    static func edgeX(
        at progress: Double,
        canvasWidth: CGFloat
    ) -> CGFloat {
        let progress = min(1, max(0, progress))
        let easedProgress = progress * progress * (3 - 2 * progress)
        let travelWidth = canvasWidth + softEdgeWidth * 2

        return canvasWidth + softEdgeWidth
            - travelWidth * easedProgress
    }

    static func visibleOnboardingWidth(
        at progress: Double,
        canvasWidth: CGFloat
    ) -> CGFloat {
        min(canvasWidth, max(0, edgeX(
            at: progress,
            canvasWidth: canvasWidth
        )))
    }
}

struct OnboardingLimitHeroMotion {
    struct Sample {
        let position: CGPoint
        let fontSize: CGFloat
    }

    let sourceFrame: CGRect
    let destinationFrame: CGRect
    let sourceFontSize: CGFloat
    let destinationFontSize: CGFloat

    func sample(at progress: Double) -> Sample {
        let progress = min(1, max(0, progress))

        return Sample(
            position: CGPoint(
                x: interpolate(
                    from: sourceFrame.midX,
                    to: destinationFrame.midX,
                    progress: progress
                ),
                y: interpolate(
                    from: sourceFrame.midY,
                    to: destinationFrame.midY,
                    progress: progress
                )
            ),
            fontSize: interpolate(
                from: sourceFontSize,
                to: destinationFontSize,
                progress: progress
            )
        )
    }

    private func interpolate(
        from start: CGFloat,
        to end: CGFloat,
        progress: Double
    ) -> CGFloat {
        start + (end - start) * progress
    }
}

struct OnboardingSavingsCardExitMotion {
    struct Sample {
        let scale: CGFloat
        let verticalOffset: CGFloat
        let opacity: Double
    }

    static func sample(at progress: Double) -> Sample {
        let progress = min(1, max(0, progress))

        return Sample(
            scale: 1 - 0.14 * progress,
            verticalOffset: -44 * progress,
            opacity: 1 - pow(progress, 2.2)
        )
    }
}

private struct OnboardingStepTransitionModifier: ViewModifier {
    let opacity: Double
    let verticalOffset: CGFloat
    let scale: CGFloat
    let blurRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .offset(y: verticalOffset)
            .scaleEffect(scale)
            .blur(radius: blurRadius)
    }
}

extension OnboardingMotionStyle {
    var animation: Animation {
        switch self {
        case .standard, .sakuraCompletion:
            .easeInOut(
                duration: OnboardingInteractionMetrics.stepAnimationDuration
            )
        case .limitConfirmation:
            .easeInOut(
                duration: OnboardingInteractionMetrics
                    .limitConfirmationAnimationDuration
            )
        case .crossfade:
            .easeInOut(
                duration: OnboardingInteractionMetrics
                    .reducedMotionAnimationDuration
            )
        }
    }

    var transition: AnyTransition {
        guard self != .crossfade, self != .limitConfirmation else {
            return .opacity
        }

        return .asymmetric(
            insertion: .modifier(
                active: OnboardingStepTransitionModifier(
                    opacity: 0,
                    verticalOffset: 18,
                    scale: 0.985,
                    blurRadius: 4
                ),
                identity: OnboardingStepTransitionModifier(
                    opacity: 1,
                    verticalOffset: 0,
                    scale: 1,
                    blurRadius: 0
                )
            ),
            removal: .modifier(
                active: OnboardingStepTransitionModifier(
                    opacity: 0,
                    verticalOffset: -16,
                    scale: 0.985,
                    blurRadius: 3
                ),
                identity: OnboardingStepTransitionModifier(
                    opacity: 1,
                    verticalOffset: 0,
                    scale: 1,
                    blurRadius: 0
                )
            )
        )
    }
}

enum OnboardingPreviewData {
    static let dailyAverageMinutes = 210
    static let initialLimitMinutes = 120
}

enum OnboardingAssetName {
    static let badgeLight = "Badge_light"
    static let badgeDark = "Badge_dark"
    static let homeScreenWidgetLight = "HomeScreenWidget_light"
    static let homeScreenWidgetDark = "HomeScreenWidget_dark"
    static let launchLogo = "LaunchLogo"
}

enum OnboardingCoordinateSpace {
    static let limitSetup = "onboarding-limit-setup"
}

enum OnboardingCompletionMaskPolicy {
    static func progress(
        showsCompletionPetals: Bool,
        transitionProgress: Double
    ) -> Double {
        showsCompletionPetals ? transitionProgress : 0
    }
}

enum OnboardingLayoutMetrics {
    static let topHeadingPadding: CGFloat = 34
    static let savingsReportMinimumHeight: CGFloat = 420
    static let lockScreenAspectRatio: CGFloat = 1.2
    static let homeScreenWidgetMaximumWidth: CGFloat = 360
    static let homeScreenWidgetCornerRadius: CGFloat = 42
    static let badgeMaximumSize: CGFloat = 270
    static let badgeCornerRadius: CGFloat = 32
}

struct OnboardingLockScreenLayout {
    let containerWidth: CGFloat
    let safeAreaTopInset: CGFloat
    let globalMinY: CGFloat

    var previewHeight: CGFloat {
        containerWidth / OnboardingLayoutMetrics.lockScreenAspectRatio
    }

    var contentTopInset: CGFloat {
        max(0, max(safeAreaTopInset, globalMinY))
    }

    var previewTopOffset: CGFloat {
        -max(0, globalMinY)
    }

    var contentPlaceholderHeight: CGFloat {
        max(0, previewHeight - contentTopInset)
    }
}

struct AdaptiveOnboardingStep<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

enum OnboardingInsightPage: Int, CaseIterable {
    case day
    case week
    case year
}
