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
    case limitCountdown
    case sakuraCompletion
    case crossfade
}

enum OnboardingElementMotionStyle: Equatable {
    case delayedSlideFromTop
    case springyPlacement
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
        if source == .savings, destination == .limitReached {
            return .limitCountdown
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

    static func homeScreenMockupStyle(
        reduceMotion: Bool
    ) -> OnboardingElementMotionStyle {
        reduceMotion ? .crossfade : .springyPlacement
    }
}

enum OnboardingInteractionMetrics {
    static let stepAnimationDuration = 0.45
    static let limitConfirmationAnimationDuration = 0.55
    static let reducedMotionAnimationDuration = 0.2
    static let lockScreenMockupDelay = 0.38
    static let lockScreenMockupAnimationDuration = 0.72
    static let homeScreenIconRevealDelay = 0.18
    static let homeScreenIconStagger = 0.045
    static let limitHeroAnimationDuration = 0.65
}

enum OnboardingLockScreenRevealMotion {
    struct Transform: Equatable {
        let offset: CGSize
        let opacity: Double
        let scale: CGFloat
        let rotationDegrees: Double

        static let identity = Transform(
            offset: .zero,
            opacity: 1,
            scale: 1,
            rotationDegrees: 0
        )
    }

    static func transform(
        isRevealed: Bool,
        previewHeight: CGFloat
    ) -> Transform {
        guard !isRevealed else { return .identity }

        return Transform(
            offset: CGSize(
                width: 0,
                height: -max(0, previewHeight)
            ),
            opacity: 1,
            scale: 1,
            rotationDegrees: 0
        )
    }
}

enum OnboardingHomeScreenPlacement {
    struct WidgetSample: Equatable {
        let offset: CGSize
        let scaleX: CGFloat
        let scaleY: CGFloat
        let opacity: Double
        let shadowOpacity: Double
        let shadowRadius: CGFloat
        let shadowY: CGFloat

        static let settled = WidgetSample(
            offset: .zero,
            scaleX: 1,
            scaleY: 1,
            opacity: 1,
            shadowOpacity: 0,
            shadowRadius: 0,
            shadowY: 0
        )
    }

    struct IconSample: Equatable {
        let offset: CGSize
        let scale: CGFloat
        let shadowOpacity: Double
        let shadowRadius: CGFloat
        let shadowY: CGFloat

        static let identity = IconSample(
            offset: .zero,
            scale: 1,
            shadowOpacity: 0,
            shadowRadius: 0,
            shadowY: 0
        )
    }

    static let entryStartTime = 0.72
    static let entryRevealDuration = 0.06
    static let approachDuration = 0.46
    static let preImpactDepthDuration = 0.22
    static let impactTime = entryStartTime + approachDuration
    static let releaseTravelDuration = 0.08
    static let releaseDuration = 0.32
    static let totalDuration = impactTime + 0.42

    private static let foregroundScale: CGFloat = 1.45
    private static let maximumIconSink: CGFloat = 0.14
    private static let maximumIconOvershoot: CGFloat = 0.045
    private static let maximumIconOffset: CGFloat = 3.5
    private static let releasePeakProgress = 0.45

    static func entryOffset(
        containerSize: CGSize,
        impactCenter: CGPoint
    ) -> CGSize {
        let foregroundCenter = CGPoint(
            x: containerSize.width * 0.50,
            y: containerSize.height * 0.52
        )

        return CGSize(
            width: foregroundCenter.x - impactCenter.x,
            height: foregroundCenter.y - impactCenter.y
        )
    }

    static func widgetSample(
        entryOffset: CGSize,
        elapsed: Double
    ) -> WidgetSample {
        guard elapsed >= entryStartTime else {
            return WidgetSample(
                offset: entryOffset,
                scaleX: foregroundScale,
                scaleY: foregroundScale,
                opacity: 0,
                shadowOpacity: 0,
                shadowRadius: 0,
                shadowY: 0
            )
        }

        if elapsed <= impactTime {
            let progress = clampedProgress(
                (elapsed - entryStartTime) / approachDuration
            )
            let easedProgress = easeOutCubic(progress)
            let depthProgress = smoothstep(progress)
            let revealProgress = clampedProgress(
                (elapsed - entryStartTime) / entryRevealDuration
            )

            return WidgetSample(
                offset: CGSize(
                    width: interpolate(
                        entryOffset.width,
                        0,
                        progress: easedProgress
                    ),
                    height: interpolate(
                        entryOffset.height,
                        0,
                        progress: easedProgress
                    )
                ),
                scaleX: interpolate(
                    foregroundScale,
                    1.035,
                    progress: depthProgress
                ),
                scaleY: interpolate(
                    foregroundScale,
                    0.965,
                    progress: depthProgress
                ),
                opacity: smoothstep(revealProgress),
                shadowOpacity: interpolate(
                    0.24,
                    0.12,
                    progress: depthProgress
                ),
                shadowRadius: interpolate(
                    22,
                    6,
                    progress: depthProgress
                ),
                shadowY: interpolate(
                    14,
                    3,
                    progress: depthProgress
                )
            )
        }

        guard elapsed < totalDuration else { return .settled }

        let settleProgress = smoothstep(clampedProgress(
            (elapsed - impactTime) / 0.28
        ))

        return WidgetSample(
            offset: .zero,
            scaleX: interpolate(1.035, 1, progress: settleProgress),
            scaleY: interpolate(0.965, 1, progress: settleProgress),
            opacity: 1,
            shadowOpacity: interpolate(0.12, 0, progress: settleProgress),
            shadowRadius: interpolate(6, 0, progress: settleProgress),
            shadowY: interpolate(3, 0, progress: settleProgress)
        )
    }

    static func iconSample(
        elementCenter: CGPoint,
        impactCenter: CGPoint,
        maximumRadius: CGFloat,
        elapsed: Double
    ) -> IconSample {
        guard maximumRadius > 0 else { return .identity }

        let dx = elementCenter.x - impactCenter.x
        let dy = elementCenter.y - impactCenter.y
        let distance = hypot(dx, dy)
        let distanceRatio = min(1, max(0, distance / maximumRadius))
        let proximity = pow(1 - distanceRatio, 1.5)
        let directionX = distance > 0 ? dx / distance : 0
        let directionY = distance > 0 ? dy / distance : 0
        let sinkScale = 1 - maximumIconSink * proximity
        let sinkOffset = -maximumIconOffset * proximity
        let sinkStartTime = impactTime - preImpactDepthDuration

        guard elapsed >= sinkStartTime else { return .identity }

        if elapsed < impactTime {
            let sinkProgress = smoothstep(clampedProgress(
                (elapsed - sinkStartTime) / preImpactDepthDuration
            ))
            let offsetMagnitude = sinkOffset * sinkProgress

            return IconSample(
                offset: CGSize(
                    width: directionX * offsetMagnitude,
                    height: directionY * offsetMagnitude
                ),
                scale: interpolate(
                    1,
                    sinkScale,
                    progress: sinkProgress
                ),
                shadowOpacity: 0,
                shadowRadius: 0,
                shadowY: 0
            )
        }

        let arrivalTime = impactTime
            + Double(distanceRatio) * releaseTravelDuration
        guard elapsed >= arrivalTime else {
            return IconSample(
                offset: CGSize(
                    width: directionX * sinkOffset,
                    height: directionY * sinkOffset
                ),
                scale: sinkScale,
                shadowOpacity: 0,
                shadowRadius: 0,
                shadowY: 0
            )
        }

        let releaseProgress = clampedProgress(
            (elapsed - arrivalTime) / releaseDuration
        )
        guard releaseProgress < 1 else { return .identity }

        let overshootScale = 1 + maximumIconOvershoot * proximity
        let reboundOffset = maximumIconOffset * 0.35 * proximity

        if releaseProgress <= releasePeakProgress {
            let riseProgress = smootherstep(clampedProgress(
                releaseProgress / releasePeakProgress
            ))
            let offsetMagnitude = interpolate(
                sinkOffset,
                reboundOffset,
                progress: riseProgress
            )

            return IconSample(
                offset: CGSize(
                    width: directionX * offsetMagnitude,
                    height: directionY * offsetMagnitude
                ),
                scale: interpolate(
                    sinkScale,
                    overshootScale,
                    progress: riseProgress
                ),
                shadowOpacity: 0.22 * proximity * riseProgress,
                shadowRadius: 10 * proximity * riseProgress,
                shadowY: 4 * proximity * riseProgress
            )
        }

        let settleProgress = smootherstep(clampedProgress(
            (releaseProgress - releasePeakProgress)
                / (1 - releasePeakProgress)
        ))
        let offsetMagnitude = interpolate(
            reboundOffset,
            0,
            progress: settleProgress
        )

        return IconSample(
            offset: CGSize(
                width: directionX * offsetMagnitude,
                height: directionY * offsetMagnitude
            ),
            scale: interpolate(
                overshootScale,
                1,
                progress: settleProgress
            ),
            shadowOpacity: 0.22 * proximity * (1 - settleProgress),
            shadowRadius: 10 * proximity * (1 - settleProgress),
            shadowY: 4 * proximity * (1 - settleProgress)
        )
    }

    private static func clampedProgress(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func smoothstep(_ progress: Double) -> Double {
        progress * progress * (3 - 2 * progress)
    }

    private static func smootherstep(_ progress: Double) -> Double {
        progress * progress * progress
            * (progress * (progress * 6 - 15) + 10)
    }

    private static func easeOutCubic(_ progress: Double) -> Double {
        1 - pow(1 - progress, 3)
    }

    private static func interpolate(
        _ start: CGFloat,
        _ end: CGFloat,
        progress: Double
    ) -> CGFloat {
        start + (end - start) * progress
    }

    private static func interpolate(
        _ start: Double,
        _ end: Double,
        progress: Double
    ) -> Double {
        start + (end - start) * progress
    }
}

struct OnboardingSakuraPetalMotion {
    struct Sample {
        let position: CGPoint
        let rotationDegrees: Double
        let opacity: Double
    }

    let delay: Double
    let baseX: CGFloat
    let wavePhase: Double
    let waveAmplitude: CGFloat
    let horizontalDrift: CGFloat
    let travelDuration: Double

    init(
        delay: Double,
        baseX: CGFloat,
        wavePhase: Double,
        waveAmplitude: CGFloat,
        horizontalDrift: CGFloat,
        travelDuration: Double? = nil
    ) {
        self.delay = delay
        self.baseX = baseX
        self.wavePhase = wavePhase
        self.waveAmplitude = waveAmplitude
        self.horizontalDrift = horizontalDrift
        self.travelDuration = travelDuration ?? max(0.001, 1 - delay)
    }

    func sample(
        at progress: Double,
        canvasHeight: CGFloat,
        petalSize: CGFloat
    ) -> Sample {
        let clampedProgress = min(1, max(0, progress))
        let localProgress = min(
            1,
            max(0, (clampedProgress - delay) / travelDuration)
        )
        let startY = -petalSize
        let endY = canvasHeight + petalSize
        let y = startY + (endY - startY) * localProgress
        let wave = sin(localProgress * .pi * 2.4 + wavePhase)
            * waveAmplitude
        let x = baseX + wave + localProgress * horizontalDrift
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
                    baseX: canvasSize.width
                        * (0.02 + random(index, salt: 3) * 0.96),
                    wavePhase: random(index, salt: 4) * .pi * 2,
                    waveAmplitude: 14 + random(index, salt: 5) * 32,
                    horizontalDrift: -18 + random(index, salt: 8) * 54,
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
    static let softEdgeHeight: CGFloat = 72

    static func onboardingTopEdgeY(
        at progress: Double,
        canvasHeight: CGFloat
    ) -> CGFloat {
        let progress = min(1, max(0, progress))
        let easedProgress = progress * progress * (3 - 2 * progress)
        let travelHeight = canvasHeight + softEdgeHeight * 2

        return -softEdgeHeight + travelHeight * easedProgress
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

enum OnboardingLimitCountdownTiming {
    static let referenceMinutes = 120.0
    static let referenceDuration = 1.7
    static let takeoffDuration = 0.70
    static let countdownStartDelay = 0.0
    static let zeroHoldDuration = 0.15
    static let handoffDuration = 1.80

    static func countdownDuration(for selectedMinutes: Int) -> TimeInterval {
        guard selectedMinutes > 0 else { return 0 }

        return referenceDuration
            * pow(Double(selectedMinutes) / referenceMinutes, 0.37)
    }
}

enum OnboardingLimitCountdownValue {
    static func remainingMinutes(
        selectedMinutes: Int,
        progress: Double,
        stepMinutes: Int = AppConfiguration.DailyLimit.stepMinutes
    ) -> Int {
        guard selectedMinutes > 0, stepMinutes > 0 else { return 0 }

        let clampedProgress = min(1, max(0, progress))
        let values = displayedValues(
            selectedMinutes: selectedMinutes,
            stepMinutes: stepMinutes
        )
        let transitionCount = values.count - 1
        let index = min(
            transitionCount,
            Int(floor(clampedProgress * Double(transitionCount)))
        )

        return values[index]
    }

    private static func displayedValues(
        selectedMinutes: Int,
        stepMinutes: Int
    ) -> [Int] {
        let finalWindow = AppConfiguration.DailyLimit
            .liveActivityWindowMinutes(forLimitMinutes: selectedMinutes)
        var values = [selectedMinutes]
        var remainingMinutes = selectedMinutes

        while remainingMinutes > finalWindow {
            remainingMinutes = max(
                finalWindow,
                ((remainingMinutes - 1) / stepMinutes) * stepMinutes
            )
            values.append(remainingMinutes)
        }

        while remainingMinutes > 0 {
            remainingMinutes -= 1
            values.append(remainingMinutes)
        }

        return values
    }
}

enum OnboardingLimitCountdownPresentation {
    static func text(
        remainingMinutes: Int,
        selectedMinutes: Int
    ) -> String {
        guard remainingMinutes > 0 else { return "Ø" }

        if selectedMinutes >= 60 {
            return String(
                format: "%dh %02dm",
                remainingMinutes / 60,
                remainingMinutes % 60
            )
        }

        return "\(remainingMinutes)m"
    }

    static func isResolutionBoundary(
        remainingMinutes: Int,
        selectedMinutes: Int
    ) -> Bool {
        guard remainingMinutes > 0, selectedMinutes > 0 else { return false }

        let dailyLimit = Double(selectedMinutes) * 60
        let currentResolution = AppConfiguration.DailyLimit
            .displayResolutionMinutes(
                remainingTime: Double(remainingMinutes) * 60,
                dailyLimit: dailyLimit
            )
        let precedingResolution = AppConfiguration.DailyLimit
            .displayResolutionMinutes(
                remainingTime: Double(remainingMinutes + 1) * 60,
                dailyLimit: dailyLimit
            )

        return currentResolution == 1
            && precedingResolution == AppConfiguration.DailyLimit.stepMinutes
    }
}

enum OnboardingLimitCountdownTextLayout {
    static let maximumFontSize: CGFloat = 164
    static let finalMarkFontSize: CGFloat = 150
    static let horizontalInset: CGFloat = 24
    static let finalMarkOpticalOffsetY: CGFloat = 4

    static func fittedFontSize(
        measuredWidthAtMaximumSize: CGFloat,
        containerWidth: CGFloat
    ) -> CGFloat {
        guard measuredWidthAtMaximumSize > 0, containerWidth > 0 else {
            return 0
        }

        let availableWidth = max(0, containerWidth - 2 * horizontalInset)
        guard availableWidth > 0 else { return 0 }

        let scale = min(1, availableWidth / measuredWidthAtMaximumSize)
        return maximumFontSize * scale
    }

    static func opticalOffsetY(progress: Double) -> CGFloat {
        finalMarkOpticalOffsetY * finalMarkProgress(progress: progress)
    }

    static func finalMarkProgress(progress: Double) -> CGFloat {
        progress >= 1 ? 1 : 0
    }
}

struct OnboardingLimitCountdownMotion {
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
        case .limitCountdown:
            .spring(
                duration: OnboardingLimitCountdownTiming.takeoffDuration,
                bounce: 0.22
            )
        case .crossfade:
            .easeInOut(
                duration: OnboardingInteractionMetrics
                    .reducedMotionAnimationDuration
            )
        }
    }

    var transition: AnyTransition {
        guard self != .crossfade,
              self != .limitConfirmation,
              self != .limitCountdown
        else {
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
