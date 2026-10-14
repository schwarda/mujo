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
                from: .lockScreenWidget,
                to: .homeScreenWidget,
                reduceMotion: false
            ) == .standard
        )
    }

    @Test("Home Screen mockup uses springy iOS-style placement")
    func homeScreenMockupUsesSpringyPlacement() {
        #expect(
            OnboardingMotionPolicy.homeScreenMockupStyle(
                reduceMotion: false
            ) == .springyPlacement
        )
    }

    @Test("Home Screen mockup respects Reduce Motion")
    func homeScreenMockupUsesCrossfadeForReduceMotion() {
        #expect(
            OnboardingMotionPolicy.homeScreenMockupStyle(
                reduceMotion: true
            ) == .crossfade
        )
    }

    @Test("Home Screen widget stays hidden before its foreground entry")
    func homeScreenWidgetStaysHiddenBeforeForegroundEntry() {
        let sample = OnboardingHomeScreenPlacement.widgetSample(
            entryOffset: CGSize(width: 90, height: 105),
            elapsed: OnboardingHomeScreenPlacement.entryStartTime - 0.001
        )

        #expect(sample.opacity == 0)
    }

    @Test("Home Screen widget appears large in front of the mockup")
    func homeScreenWidgetAppearsLargeInFront() {
        let sample = OnboardingHomeScreenPlacement.widgetSample(
            entryOffset: CGSize(width: 90, height: 105),
            elapsed: OnboardingHomeScreenPlacement.entryStartTime
                + OnboardingHomeScreenPlacement.entryRevealDuration
        )

        #expect(sample.opacity == 1)
        #expect(sample.scaleX > 1.30)
        #expect(sample.scaleY > 1.30)
        #expect(sample.offset.width > 0)
        #expect(sample.offset.height > 0)
    }

    @Test("Home Screen widget recedes monotonically toward its slot")
    func homeScreenWidgetRecedesMonotonicallyTowardSlot() {
        let entryOffset = CGSize(width: 90, height: 105)
        let early = OnboardingHomeScreenPlacement.widgetSample(
            entryOffset: entryOffset,
            elapsed: OnboardingHomeScreenPlacement.entryStartTime + 0.08
        )
        let late = OnboardingHomeScreenPlacement.widgetSample(
            entryOffset: entryOffset,
            elapsed: OnboardingHomeScreenPlacement.impactTime - 0.04
        )
        let impact = OnboardingHomeScreenPlacement.widgetSample(
            entryOffset: entryOffset,
            elapsed: OnboardingHomeScreenPlacement.impactTime
        )

        #expect(hypot(late.offset.width, late.offset.height)
            < hypot(early.offset.width, early.offset.height))
        #expect(late.scaleX < early.scaleX)
        #expect(late.scaleY < early.scaleY)
        #expect(abs(impact.offset.width) < 0.000_001)
        #expect(abs(impact.offset.height) < 0.000_001)
    }

    @Test("Home Screen foreground origin scales with its container")
    func homeScreenForegroundOriginScalesWithContainer() {
        let smallSize = CGSize(width: 320, height: 330)
        let largeSize = CGSize(width: 640, height: 660)
        let small = OnboardingHomeScreenPlacement.entryOffset(
            containerSize: smallSize,
            impactCenter: CGPoint(
                x: smallSize.width * 0.274,
                y: smallSize.height * 0.257
            )
        )
        let large = OnboardingHomeScreenPlacement.entryOffset(
            containerSize: largeSize,
            impactCenter: CGPoint(
                x: largeSize.width * 0.274,
                y: largeSize.height * 0.257
            )
        )

        #expect(small.width > 0)
        #expect(small.height > 0)
        #expect(abs(small.width / smallSize.width
            - large.width / largeSize.width) < 0.000_001)
        #expect(abs(small.height / smallSize.height
            - large.height / largeSize.height) < 0.000_001)
    }

    @Test("Home Screen dock has equal inner and outer spacing")
    func homeScreenDockHasEqualSpacing() {
        let centers = OnboardingHomeScreenLayout.dockIconCenters
        let iconWidth = 240.0 / 1_206.0
        let expectedGap = (0.963 - 0.037 - 4 * iconWidth) / 5
        let gaps = [
            centers[0] - iconWidth / 2 - 0.037,
            centers[1] - centers[0] - iconWidth,
            centers[2] - centers[1] - iconWidth,
            centers[3] - centers[2] - iconWidth,
            0.963 - centers[3] - iconWidth / 2,
        ]

        #expect(centers.count == 4)
        #expect(gaps.allSatisfy { abs($0 - expectedGap) < 0.000_001 })
    }

    @Test("Home Screen second-row icons align with the widget bottom")
    func homeScreenSecondRowAlignsWithWidgetBottom() {
        let widgetBottom = (52.0 + 540.0) / 1_245.0
        let iconBottom = OnboardingHomeScreenLayout.secondRowIconCenterY
            + 120.0 / 1_245.0

        #expect(abs(widgetBottom - iconBottom) < 0.000_001)
    }

    @Test("Home Screen top grid has symmetric outer and inner spacing")
    func homeScreenTopGridHasSymmetricHorizontalSpacing() {
        let width = OnboardingHomeScreenLayout.referenceSize.width
        let widgetWidth = OnboardingHomeScreenLayout.widgetSize * width
        let iconWidth = OnboardingHomeScreenLayout.iconSize * width
        let widgetCenterX = OnboardingHomeScreenLayout.widgetCenter.x * width
        let iconCenters = OnboardingHomeScreenLayout.topIconColumnCenters.map {
            $0 * width
        }
        let gaps = [
            widgetCenterX - widgetWidth / 2,
            iconCenters[0] - iconWidth / 2
                - (widgetCenterX + widgetWidth / 2),
            iconCenters[1] - iconWidth / 2
                - (iconCenters[0] + iconWidth / 2),
            width - (iconCenters[1] + iconWidth / 2),
        ]

        #expect(iconCenters.count == 2)
        #expect(abs(gaps[0] - gaps[3]) < 0.000_001)
        #expect(abs(gaps[1] - gaps[2]) < 0.000_001)
    }

    @Test("Home Screen top grid aligns to the same vertical edges")
    func homeScreenTopGridHasSymmetricVerticalSpacing() {
        let size = OnboardingHomeScreenLayout.referenceSize
        let widgetHeight = OnboardingHomeScreenLayout.widgetSize * size.width
        let iconHeight = OnboardingHomeScreenLayout.iconSize * size.width
        let widgetCenterY = OnboardingHomeScreenLayout.widgetCenter.y
            * size.height
        let firstCenterY = OnboardingHomeScreenLayout.firstRowIconCenterY
            * size.height
        let secondCenterY = OnboardingHomeScreenLayout.secondRowIconCenterY
            * size.height

        #expect(abs(
            widgetCenterY - widgetHeight / 2
                - (firstCenterY - iconHeight / 2)
        ) < 0.000_001)
        #expect(abs(
            widgetCenterY + widgetHeight / 2
                - (secondCenterY + iconHeight / 2)
        ) < 0.000_001)
    }

    @Test("Home Screen icons sink before impact according to proximity")
    func homeScreenIconsSinkBeforeImpactByProximity() {
        let elapsed = OnboardingHomeScreenPlacement.impactTime - 0.06
        let near = OnboardingHomeScreenPlacement.iconSample(
            elementCenter: CGPoint(x: 40, y: 0),
            impactCenter: .zero,
            maximumRadius: 400,
            elapsed: elapsed
        )
        let far = OnboardingHomeScreenPlacement.iconSample(
            elementCenter: CGPoint(x: 320, y: 0),
            impactCenter: .zero,
            maximumRadius: 400,
            elapsed: elapsed
        )

        #expect(near.scale < 1)
        #expect(far.scale < 1)
        #expect(abs(1 - near.scale) > abs(1 - far.scale))
    }

    @Test("Home Screen wave has a strong depth field at impact")
    func homeScreenWaveHasStrongDepthAtImpact() {
        let nearest = OnboardingHomeScreenPlacement.iconSample(
            elementCenter: .zero,
            impactCenter: .zero,
            maximumRadius: 400,
            elapsed: OnboardingHomeScreenPlacement.impactTime
        )
        let nearby = OnboardingHomeScreenPlacement.iconSample(
            elementCenter: CGPoint(x: 1, y: 0),
            impactCenter: .zero,
            maximumRadius: 400,
            elapsed: OnboardingHomeScreenPlacement.impactTime
        )
        let middle = OnboardingHomeScreenPlacement.iconSample(
            elementCenter: CGPoint(x: 200, y: 0),
            impactCenter: .zero,
            maximumRadius: 400,
            elapsed: OnboardingHomeScreenPlacement.impactTime
        )

        #expect(nearest.scale <= 0.86)
        #expect(hypot(nearby.offset.width, nearby.offset.height) >= 3.45)
        #expect(middle.scale < 0.96)
    }

    @Test("Home Screen widget has a stronger contact squash")
    func homeScreenWidgetHasStrongerContactSquash() {
        let impact = OnboardingHomeScreenPlacement.widgetSample(
            entryOffset: CGSize(width: 90, height: 105),
            elapsed: OnboardingHomeScreenPlacement.impactTime
        )

        #expect(impact.scaleX >= 1.035)
        #expect(impact.scaleY <= 0.965)
        #expect(impact.shadowOpacity >= 0.12)
    }

    @Test("Home Screen icon response has no dead zone at impact")
    func homeScreenIconResponseHasNoImpactDeadZone() {
        let times = [
            OnboardingHomeScreenPlacement.impactTime - 0.01,
            OnboardingHomeScreenPlacement.impactTime,
            OnboardingHomeScreenPlacement.impactTime + 0.01,
        ]
        let samples = times.map {
            OnboardingHomeScreenPlacement.iconSample(
                elementCenter: CGPoint(x: 40, y: 0),
                impactCenter: .zero,
                maximumRadius: 400,
                elapsed: $0
            )
        }

        #expect(samples.allSatisfy { $0 != .identity })
        #expect(abs(samples[1].scale - samples[0].scale) < 0.03)
        #expect(abs(samples[2].scale - samples[1].scale) < 0.03)
    }

    @Test("Home Screen icon depth field is radially symmetric")
    func homeScreenIconDepthIsRadiallySymmetric() {
        let elapsed = OnboardingHomeScreenPlacement.impactTime - 0.06
        let right = OnboardingHomeScreenPlacement.iconSample(
            elementCenter: CGPoint(x: 100, y: 0),
            impactCenter: .zero,
            maximumRadius: 400,
            elapsed: elapsed
        )
        let down = OnboardingHomeScreenPlacement.iconSample(
            elementCenter: CGPoint(x: 0, y: 100),
            impactCenter: .zero,
            maximumRadius: 400,
            elapsed: elapsed
        )

        #expect(abs(right.scale - down.scale) < 0.000_001)
        #expect(abs(right.shadowOpacity - down.shadowOpacity) < 0.000_001)
        #expect(abs(right.shadowRadius - down.shadowRadius) < 0.000_001)
        #expect(abs(
            hypot(right.offset.width, right.offset.height)
                - hypot(down.offset.width, down.offset.height)
        ) < 0.000_001)
    }

    @Test("Home Screen icon release travels outward")
    func homeScreenIconReleaseTravelsOutward() {
        let nearAtImpact = OnboardingHomeScreenPlacement.iconSample(
            elementCenter: CGPoint(x: 40, y: 0),
            impactCenter: .zero,
            maximumRadius: 400,
            elapsed: OnboardingHomeScreenPlacement.impactTime
        )
        let nearAfterImpact = OnboardingHomeScreenPlacement.iconSample(
            elementCenter: CGPoint(x: 40, y: 0),
            impactCenter: .zero,
            maximumRadius: 400,
            elapsed: OnboardingHomeScreenPlacement.impactTime + 0.02
        )
        let farAtImpact = OnboardingHomeScreenPlacement.iconSample(
            elementCenter: CGPoint(x: 320, y: 0),
            impactCenter: .zero,
            maximumRadius: 400,
            elapsed: OnboardingHomeScreenPlacement.impactTime
        )
        let farAfterImpact = OnboardingHomeScreenPlacement.iconSample(
            elementCenter: CGPoint(x: 320, y: 0),
            impactCenter: .zero,
            maximumRadius: 400,
            elapsed: OnboardingHomeScreenPlacement.impactTime + 0.02
        )

        #expect(nearAfterImpact.scale > nearAtImpact.scale)
        #expect(abs(farAfterImpact.scale - farAtImpact.scale) < 0.000_001)
    }

    @Test("Home Screen icons have one small rebound")
    func homeScreenIconHasOneSmallRebound() {
        let sample: (Double) -> OnboardingHomeScreenPlacement.IconSample = {
            OnboardingHomeScreenPlacement.iconSample(
                elementCenter: .zero,
                impactCenter: .zero,
                maximumRadius: 400,
                elapsed: OnboardingHomeScreenPlacement.impactTime + $0
            )
        }
        let peak = sample(OnboardingHomeScreenPlacement.releaseDuration * 0.45)
        let settling = [sample(0.18), sample(0.23), sample(0.28), sample(0.32)]

        #expect(peak.scale >= 1.04)
        #expect(peak.scale <= 1.045_001)
        #expect(peak.shadowOpacity >= 0.20)
        #expect(peak.shadowRadius >= 9)
        #expect(peak.shadowY >= 3.5)
        #expect(settling.allSatisfy { $0.scale >= 1 })
        #expect(settling[0].scale >= settling[1].scale)
        #expect(settling[1].scale >= settling[2].scale)
        #expect(settling[2].scale >= settling[3].scale)
        #expect(abs(settling[3].scale - 1) < 0.000_001)
    }

    @Test("Home Screen icon rebound changes direction without a jerk")
    func homeScreenIconReboundHasSmoothPeak() {
        let step = 0.002
        let peakTime = OnboardingHomeScreenPlacement.impactTime
            + OnboardingHomeScreenPlacement.releaseDuration * 0.45
        let scale: (Double) -> Double = { elapsed in
            Double(OnboardingHomeScreenPlacement.iconSample(
                elementCenter: .zero,
                impactCenter: .zero,
                maximumRadius: 400,
                elapsed: elapsed
            ).scale)
        }
        let leftAcceleration = (
            scale(peakTime)
                - 2 * scale(peakTime - step)
                + scale(peakTime - 2 * step)
        ) / (step * step)
        let rightAcceleration = (
            scale(peakTime + 2 * step)
                - 2 * scale(peakTime + step)
                + scale(peakTime)
        ) / (step * step)

        #expect(abs(leftAcceleration - rightAcceleration) < 10)
    }

    @Test("Home Screen icon rebound settles without a final jerk")
    func homeScreenIconReboundHasSmoothEnding() {
        let step = 0.002
        let endTime = OnboardingHomeScreenPlacement.impactTime
            + OnboardingHomeScreenPlacement.releaseDuration
        let scale: (Double) -> Double = { elapsed in
            Double(OnboardingHomeScreenPlacement.iconSample(
                elementCenter: .zero,
                impactCenter: .zero,
                maximumRadius: 400,
                elapsed: elapsed
            ).scale)
        }
        let endingAcceleration = (
            scale(endTime)
                - 2 * scale(endTime - step)
                + scale(endTime - 2 * step)
        ) / (step * step)

        #expect(abs(endingAcceleration) < 4)
    }

    @Test("Home Screen placement handles nonpositive radius")
    func homeScreenPlacementHandlesNonpositiveRadius() {
        let zero = OnboardingHomeScreenPlacement.iconSample(
            elementCenter: CGPoint(x: 40, y: 0),
            impactCenter: .zero,
            maximumRadius: 0,
            elapsed: OnboardingHomeScreenPlacement.impactTime
        )
        let negative = OnboardingHomeScreenPlacement.iconSample(
            elementCenter: CGPoint(x: 40, y: 0),
            impactCenter: .zero,
            maximumRadius: -1,
            elapsed: OnboardingHomeScreenPlacement.impactTime
        )

        #expect(zero == .identity)
        #expect(negative == .identity)
    }

    @Test("Home Screen placement settles widget and icons")
    func homeScreenPlacementSettles() {
        let widget = OnboardingHomeScreenPlacement.widgetSample(
            entryOffset: CGSize(width: 90, height: 105),
            elapsed: OnboardingHomeScreenPlacement.totalDuration
        )
        let icon = OnboardingHomeScreenPlacement.iconSample(
            elementCenter: CGPoint(x: 320, y: 360),
            impactCenter: CGPoint(x: 90, y: 80),
            maximumRadius: 450,
            elapsed: OnboardingHomeScreenPlacement.totalDuration
        )

        #expect(widget.offset == .zero)
        #expect(widget.scaleX == 1)
        #expect(widget.scaleY == 1)
        #expect(widget.opacity == 1)
        #expect(widget.shadowOpacity == 0)
        #expect(widget.shadowRadius == 0)
        #expect(widget.shadowY == 0)
        #expect(icon.offset == .zero)
        #expect(icon.scale == 1)
        #expect(icon.shadowOpacity == 0)
        #expect(icon.shadowRadius == 0)
        #expect(icon.shadowY == 0)
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

    @Test("Savings countdown carries the selected limit into the reached state")
    func limitCountdownUsesSharedValue() {
        #expect(
            OnboardingMotionPolicy.style(
                from: .savings,
                to: .limitReached,
                reduceMotion: false
            ) == .limitCountdown
        )
    }

    @Test("Countdown duration follows the square-root curve")
    func countdownDurationUsesSelectedLimit() {
        #expect(
            abs(OnboardingLimitCountdownTiming.countdownDuration(for: 15)
                - 0.707_106_781_2) < 0.000_001
        )
        #expect(
            OnboardingLimitCountdownTiming.countdownDuration(for: 120) == 2
        )
        #expect(
            abs(OnboardingLimitCountdownTiming.countdownDuration(for: 720)
                - 4.898_979_486) < 0.000_001
        )
        #expect(
            OnboardingLimitCountdownTiming.countdownDuration(for: 0) == 0
        )
        #expect(
            OnboardingLimitCountdownTiming.countdownDuration(for: -15) == 0
        )
    }

    @Test("Countdown starts immediately before a slower image handoff")
    func countdownStartsImmediatelyBeforeSlowerHandoff() {
        #expect(OnboardingLimitCountdownTiming.takeoffDuration == 0.70)
        #expect(OnboardingLimitCountdownTiming.countdownStartDelay == 0)
        #expect(OnboardingLimitCountdownTiming.zeroHoldDuration == 0.15)
        #expect(OnboardingLimitCountdownTiming.handoffDuration == 1.20)
    }

    @Test("Countdown values stay stepped, clamped, and monotonic")
    func countdownValuesRespectDialSteps() {
        let progressValues = stride(from: -0.1, through: 1.1, by: 0.01)
        let offStepValues = progressValues.map {
            OnboardingLimitCountdownValue.remainingMinutes(
                selectedMinutes: 125,
                progress: $0
            )
        }
        let firstDecreaseIndex = offStepValues.firstIndex { $0 < 125 }
        let valuesAfterFirstDecrease = firstDecreaseIndex.map {
            offStepValues[$0...]
        } ?? []

        #expect(offStepValues.first == 125)
        #expect(offStepValues.last == 0)
        #expect(offStepValues.allSatisfy { $0 >= 0 && $0 <= 125 })
        #expect(valuesAfterFirstDecrease.allSatisfy {
            $0 <= 15 || $0.isMultiple(of: 15)
        })
        #expect(zip(offStepValues, offStepValues.dropFirst()).allSatisfy {
            $0 >= $1
        })

        let alignedValues = progressValues.map {
            OnboardingLimitCountdownValue.remainingMinutes(
                selectedMinutes: 120,
                progress: $0
            )
        }
        #expect(alignedValues.allSatisfy {
            $0 <= 15 || $0.isMultiple(of: 15)
        })
        #expect(
            OnboardingLimitCountdownValue.remainingMinutes(
                selectedMinutes: 120,
                progress: -1
            ) == 120
        )
        #expect(
            OnboardingLimitCountdownValue.remainingMinutes(
                selectedMinutes: 120,
                progress: 1
            ) == 0
        )
        #expect(
            OnboardingLimitCountdownValue.remainingMinutes(
                selectedMinutes: 0,
                progress: 0.5
            ) == 0
        )
    }

    @Test("Every visible countdown value gets the same share of its run")
    func countdownUsesAnEvenVisualCadence() {
        let transitionCount = 22.0
        let oneStep = 1 / transitionCount

        #expect(
            OnboardingLimitCountdownValue.remainingMinutes(
                selectedMinutes: 120,
                progress: oneStep * 0.5
            ) == 120
        )
        #expect(
            OnboardingLimitCountdownValue.remainingMinutes(
                selectedMinutes: 120,
                progress: oneStep + 0.000_001
            ) == 105
        )
        #expect(
            OnboardingLimitCountdownValue.remainingMinutes(
                selectedMinutes: 120,
                progress: 7 * oneStep + 0.000_001
            ) == 15
        )
        #expect(
            OnboardingLimitCountdownValue.remainingMinutes(
                selectedMinutes: 120,
                progress: 8 * oneStep + 0.000_001
            ) == 14
        )
    }

    @Test("Long limits advance visible values faster than short limits")
    func longerLimitsUseAFasterVisualCadence() {
        let elapsedTime = 0.07
        let oneHourProgress = elapsedTime
            / OnboardingLimitCountdownTiming.countdownDuration(for: 60)
        let twelveHourProgress = elapsedTime
            / OnboardingLimitCountdownTiming.countdownDuration(for: 720)

        #expect(
            OnboardingLimitCountdownValue.remainingMinutes(
                selectedMinutes: 60,
                progress: oneHourProgress
            ) == 60
        )
        #expect(
            OnboardingLimitCountdownValue.remainingMinutes(
                selectedMinutes: 720,
                progress: twelveHourProgress
            ) == 705
        )
    }

    @Test("Countdown adopts the app's adaptive remaining-time resolution")
    func countdownUsesSharedRemainingTimeResolution() {
        #expect(
            OnboardingLimitCountdownValue.remainingMinutes(
                selectedMinutes: 120,
                progress: 7.0 / 22.0 + 0.000_001
            ) == 15
        )
        #expect(
            OnboardingLimitCountdownValue.remainingMinutes(
                selectedMinutes: 120,
                progress: 8.0 / 22.0 + 0.000_001
            ) == 14
        )
        #expect(
            OnboardingLimitCountdownValue.remainingMinutes(
                selectedMinutes: 240,
                progress: 13.0 / 44.0 + 0.000_001
            ) == 45
        )
        #expect(
            OnboardingLimitCountdownValue.remainingMinutes(
                selectedMinutes: 240,
                progress: 15.0 / 44.0 + 0.000_001
            ) == 29
        )
    }

    @Test("Countdown keeps the format received from the savings screen")
    func countdownKeepsItsInitialFormat() {
        #expect(
            OnboardingLimitCountdownPresentation.text(
                remainingMinutes: 120,
                selectedMinutes: 120
            ) == "2h 00m"
        )
        #expect(
            OnboardingLimitCountdownPresentation.text(
                remainingMinutes: 14,
                selectedMinutes: 120
            ) == "0h 14m"
        )
        #expect(
            OnboardingLimitCountdownPresentation.text(
                remainingMinutes: 45,
                selectedMinutes: 45
            ) == "45m"
        )
        #expect(
            OnboardingLimitCountdownPresentation.text(
                remainingMinutes: 1,
                selectedMinutes: 45
            ) == "1m"
        )
        #expect(
            OnboardingLimitCountdownPresentation.text(
                remainingMinutes: 0,
                selectedMinutes: 120
            ) == "Ø"
        )
    }

    @Test("Switching to minute steps does not animate the number change")
    func countdownResolutionBoundaryIsImmediate() {
        #expect(
            OnboardingLimitCountdownPresentation.isResolutionBoundary(
                remainingMinutes: 15,
                selectedMinutes: 120
            )
        )
        #expect(
            OnboardingLimitCountdownPresentation.isResolutionBoundary(
                remainingMinutes: 30,
                selectedMinutes: 240
            )
        )
        #expect(
            !OnboardingLimitCountdownPresentation.isResolutionBoundary(
                remainingMinutes: 14,
                selectedMinutes: 120
            )
        )
    }

    @Test("Countdown text fitting keeps every value inside horizontal margins")
    func countdownTextFitsAvailableWidth() {
        #expect(
            OnboardingLimitCountdownTextLayout.fittedFontSize(
                measuredWidthAtMaximumSize: 280,
                containerWidth: 390
            ) == 164
        )

        let fittedSize = OnboardingLimitCountdownTextLayout.fittedFontSize(
            measuredWidthAtMaximumSize: 410,
            containerWidth: 390
        )
        let expectedSize: CGFloat = 164 * 342 / 410
        let renderedWidth = 410 * fittedSize / 164

        #expect(abs(fittedSize - expectedSize) < 0.000_001)
        #expect(renderedWidth <= 342.000_001)
        #expect(
            OnboardingLimitCountdownTextLayout.fittedFontSize(
                measuredWidthAtMaximumSize: 0,
                containerWidth: 390
            ) == 0
        )
        #expect(
            OnboardingLimitCountdownTextLayout.fittedFontSize(
                measuredWidthAtMaximumSize: 100,
                containerWidth: 0
            ) == 0
        )
        #expect(
            OnboardingLimitCountdownTextLayout.fittedFontSize(
                measuredWidthAtMaximumSize: -100,
                containerWidth: -390
            ).isFinite
        )
    }

    @Test("Final mark geometry starts only after the numbers finish")
    func countdownGeometryStaysFixedUntilFinalMark() {
        #expect(
            OnboardingLimitCountdownTextLayout.opticalOffsetY(progress: 0) == 0
        )
        #expect(
            OnboardingLimitCountdownTextLayout.opticalOffsetY(progress: 0.85)
                == 0
        )
        #expect(
            OnboardingLimitCountdownTextLayout.opticalOffsetY(progress: 0.999)
                == 0
        )
        #expect(
            OnboardingLimitCountdownTextLayout.opticalOffsetY(progress: 1) == 4
        )
    }

    @Test("Countdown motion reaches measured geometry and requested font sizes")
    func countdownMotionInterpolatesMeasuredFrames() {
        let motion = OnboardingLimitCountdownMotion(
            sourceFrame: CGRect(x: 20, y: 80, width: 120, height: 40),
            destinationFrame: CGRect(x: 140, y: 280, width: 220, height: 220),
            sourceFontSize: 20,
            destinationFontSize: 164
        )

        let start = motion.sample(at: 0)
        let middle = motion.sample(at: 0.5)
        let end = motion.sample(at: 1)

        #expect(start.position == CGPoint(x: 80, y: 100))
        #expect(middle.position == CGPoint(x: 165, y: 245))
        #expect(end.position == CGPoint(x: 250, y: 390))
        #expect(start.fontSize == 20)
        #expect(middle.fontSize == 92)
        #expect(end.fontSize == 164)
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

    @Test("Lock Screen enters fully from above without fading or tilting")
    func lockScreenRevealUsesAFullHeightVerticalTranslation() {
        let hidden = OnboardingLockScreenRevealMotion.transform(
            isRevealed: false,
            previewHeight: 325
        )
        let revealed = OnboardingLockScreenRevealMotion.transform(
            isRevealed: true,
            previewHeight: 325
        )

        #expect(hidden.offset == CGSize(width: 0, height: -325))
        #expect(hidden.opacity == 1)
        #expect(hidden.scale == 1)
        #expect(hidden.rotationDegrees == 0)
        #expect(revealed == .identity)
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
            baseX: 120,
            wavePhase: 0,
            waveAmplitude: 24,
            horizontalDrift: 26
        )

        let start = motion.sample(
            at: 0,
            canvasHeight: 600,
            petalSize: 20
        )
        let middle = motion.sample(
            at: 0.5,
            canvasHeight: 600,
            petalSize: 20
        )
        let end = motion.sample(
            at: 1,
            canvasHeight: 600,
            petalSize: 20
        )

        #expect(start.opacity == 0)
        #expect(middle.opacity > 0.9)
        #expect(end.opacity == 0)
        #expect(start.position.y < middle.position.y)
        #expect(middle.position.y < end.position.y)
    }

    @Test("Sakura gust masks the screen when Home is revealed")
    func sakuraGustCoversScreenAtHomeReveal() {
        let canvasSize = CGSize(width: 390, height: 844)
        let samples = OnboardingSakuraGust.petals(in: canvasSize).map {
            $0.motion.sample(
                at: OnboardingSakuraGust.homeRevealProgress,
                canvasHeight: canvasSize.height,
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

    @Test("Sakura gust reveals Home continuously from top to bottom")
    func sakuraGustUsesDirectionalReveal() {
        let height: CGFloat = 844
        let start = OnboardingSakuraWipe.onboardingTopEdgeY(
            at: 0,
            canvasHeight: height
        )
        let quarter = OnboardingSakuraWipe.onboardingTopEdgeY(
            at: 0.25,
            canvasHeight: height
        )
        let middle = OnboardingSakuraWipe.onboardingTopEdgeY(
            at: 0.5,
            canvasHeight: height
        )
        let end = OnboardingSakuraWipe.onboardingTopEdgeY(
            at: 1,
            canvasHeight: height
        )

        #expect(start < 0)
        #expect(quarter > start)
        #expect(middle > quarter)
        #expect(middle > 300 && middle < 544)
        #expect(end > height)
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
