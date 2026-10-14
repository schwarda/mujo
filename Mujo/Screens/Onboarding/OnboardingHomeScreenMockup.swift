import SwiftUI

enum OnboardingHomeScreenLayout {
    static let referenceSize = CGSize(width: 1_206, height: 1_245)
    static let aspectRatio = referenceSize.width / referenceSize.height

    private static let widgetPixelSize: CGFloat = 540
    private static let iconPixelSize: CGFloat = 240
    private static let outerHorizontalPadding: CGFloat = 56
    private static let horizontalGap: CGFloat = 37
    private static let topPadding: CGFloat = 52
    private static let verticalGap: CGFloat = 60

    static let widgetSize = widgetPixelSize / referenceSize.width
    static let iconSize = iconPixelSize / referenceSize.width

    static let widgetCenter = CGPoint(
        x: (outerHorizontalPadding + widgetPixelSize / 2)
            / referenceSize.width,
        y: (topPadding + widgetPixelSize / 2) / referenceSize.height
    )

    static let topIconColumnCenters: [CGFloat] = {
        let first = outerHorizontalPadding + widgetPixelSize
            + horizontalGap + iconPixelSize / 2
        return [
            first / referenceSize.width,
            (first + iconPixelSize + horizontalGap) / referenceSize.width,
        ]
    }()

    static let firstRowIconCenterY = (topPadding + iconPixelSize / 2)
        / referenceSize.height
    static let secondRowIconCenterY = (
        topPadding + iconPixelSize + verticalGap + iconPixelSize / 2
    ) / referenceSize.height

    static let dockIconCenters: [CGFloat] = {
        let dockMinX: CGFloat = 0.037
        let dockMaxX: CGFloat = 0.963
        let iconCount = 4
        let gap = (
            dockMaxX - dockMinX - CGFloat(iconCount) * iconSize
        ) / CGFloat(iconCount + 1)

        return (0..<iconCount).map { index in
            dockMinX + gap + iconSize / 2
                + CGFloat(index) * (iconSize + gap)
        }
    }()
}

struct OnboardingHomeScreenMockup: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var iconsVisible = false
    @State private var placementElapsed = 0.0

    private static let icons = [
        IconLayout(
            id: "settings",
            assetName: "HomeScreenMockupSettings",
            center: CGPoint(
                x: OnboardingHomeScreenLayout.topIconColumnCenters[0],
                y: OnboardingHomeScreenLayout.firstRowIconCenterY
            )
        ),
        IconLayout(
            id: "health",
            assetName: "HomeScreenMockupHealth",
            center: CGPoint(
                x: OnboardingHomeScreenLayout.topIconColumnCenters[1],
                y: OnboardingHomeScreenLayout.firstRowIconCenterY
            )
        ),
        IconLayout(
            id: "photos",
            assetName: "HomeScreenMockupPhotos",
            center: CGPoint(
                x: OnboardingHomeScreenLayout.topIconColumnCenters[0],
                y: OnboardingHomeScreenLayout.secondRowIconCenterY
            )
        ),
        IconLayout(
            id: "notes",
            assetName: "HomeScreenMockupNotes",
            center: CGPoint(
                x: OnboardingHomeScreenLayout.topIconColumnCenters[1],
                y: OnboardingHomeScreenLayout.secondRowIconCenterY
            )
        ),
        IconLayout(
            id: "phone",
            assetName: "HomeScreenMockupPhone",
            center: CGPoint(
                x: OnboardingHomeScreenLayout.dockIconCenters[0],
                y: 0.838
            )
        ),
        IconLayout(
            id: "safari",
            assetName: "HomeScreenMockupSafari",
            center: CGPoint(
                x: OnboardingHomeScreenLayout.dockIconCenters[1],
                y: 0.838
            )
        ),
        IconLayout(
            id: "messages",
            assetName: "HomeScreenMockupMessages",
            center: CGPoint(
                x: OnboardingHomeScreenLayout.dockIconCenters[2],
                y: 0.838
            )
        ),
        IconLayout(
            id: "camera",
            assetName: "HomeScreenMockupCamera",
            center: CGPoint(
                x: OnboardingHomeScreenLayout.dockIconCenters[3],
                y: 0.838
            )
        ),
    ]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let impactCenter = point(
                for: OnboardingHomeScreenLayout.widgetCenter,
                in: size
            )
            let entryOffset = OnboardingHomeScreenPlacement.entryOffset(
                containerSize: size,
                impactCenter: impactCenter
            )
            let maximumRadius = hypot(size.width, size.height) * 0.72

            ZStack(alignment: .topLeading) {
                Image("HomeScreenMockupBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()

                ForEach(Array(Self.icons.enumerated()), id: \.element.id) {
                    index, icon in
                    let center = point(for: icon.center, in: size)

                    Image(icon.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: size.width
                                * OnboardingHomeScreenLayout.iconSize,
                            height: size.width
                                * OnboardingHomeScreenLayout.iconSize
                        )
                        .position(center)
                        .scaleEffect(
                            iconsVisible || reduceMotion ? 1 : 0.82
                        )
                        .opacity(iconsVisible ? 1 : 0)
                        .animation(
                            .spring(duration: 0.42, bounce: 0.16)
                                .delay(
                                    OnboardingInteractionMetrics
                                        .homeScreenIconRevealDelay
                                        + Double(index)
                                        * OnboardingInteractionMetrics
                                            .homeScreenIconStagger
                                ),
                            value: iconsVisible
                        )
                        .modifier(
                            HomeScreenIconPlacementModifier(
                                elementCenter: center,
                                impactCenter: impactCenter,
                                maximumRadius: maximumRadius,
                                elapsed: reduceMotion
                                    ? OnboardingHomeScreenPlacement
                                        .totalDuration
                                    : placementElapsed
                            )
                        )
                }

                Image("HomeScreenMockupWidget")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: size.width
                            * OnboardingHomeScreenLayout.widgetSize,
                        height: size.width
                            * OnboardingHomeScreenLayout.widgetSize
                    )
                    .position(impactCenter)
                    .modifier(
                        HomeScreenWidgetPlacementModifier(
                            entryOffset: entryOffset,
                            elapsed: reduceMotion
                                ? OnboardingHomeScreenPlacement.totalDuration
                                : placementElapsed
                        )
                    )
                    .zIndex(1)
            }
        }
        .aspectRatio(
            OnboardingHomeScreenLayout.aspectRatio,
            contentMode: .fit
        )
        .clipShape(.rect(
            cornerRadius: OnboardingLayoutMetrics
                .homeScreenWidgetCornerRadius
        ))
        .shadow(
            color: Color.accentColor.opacity(0.4),
            radius: 18,
            y: 10
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mujø Home Screen widget preview")
        .onAppear(perform: startAnimation)
    }

    private func point(
        for normalizedPoint: CGPoint,
        in size: CGSize
    ) -> CGPoint {
        CGPoint(
            x: normalizedPoint.x * size.width,
            y: normalizedPoint.y * size.height
        )
    }

    private func startAnimation() {
        let style = OnboardingMotionPolicy.homeScreenMockupStyle(
            reduceMotion: reduceMotion
        )

        guard style == .springyPlacement else {
            withAnimation(.easeInOut(
                duration: OnboardingInteractionMetrics
                    .reducedMotionAnimationDuration
            )) {
                iconsVisible = true
                placementElapsed = OnboardingHomeScreenPlacement.totalDuration
            }
            return
        }

        iconsVisible = true

        withAnimation(
            .linear(
                duration: OnboardingHomeScreenPlacement.totalDuration
            )
        ) {
            placementElapsed = OnboardingHomeScreenPlacement.totalDuration
        }
    }
}

private struct HomeScreenIconPlacementModifier: AnimatableModifier {
    let elementCenter: CGPoint
    let impactCenter: CGPoint
    let maximumRadius: CGFloat
    var elapsed: Double

    var animatableData: Double {
        get { elapsed }
        set { elapsed = newValue }
    }

    func body(content: Content) -> some View {
        let sample = OnboardingHomeScreenPlacement.iconSample(
            elementCenter: elementCenter,
            impactCenter: impactCenter,
            maximumRadius: maximumRadius,
            elapsed: elapsed
        )

        content
            .scaleEffect(sample.scale)
            .offset(sample.offset)
            .shadow(
                color: .black.opacity(sample.shadowOpacity),
                radius: sample.shadowRadius,
                y: sample.shadowY
            )
    }
}

private struct HomeScreenWidgetPlacementModifier: AnimatableModifier {
    let entryOffset: CGSize
    var elapsed: Double

    var animatableData: Double {
        get { elapsed }
        set { elapsed = newValue }
    }

    func body(content: Content) -> some View {
        let sample = OnboardingHomeScreenPlacement.widgetSample(
            entryOffset: entryOffset,
            elapsed: elapsed
        )

        content
            .scaleEffect(x: sample.scaleX, y: sample.scaleY)
            .offset(sample.offset)
            .opacity(sample.opacity)
            .shadow(
                color: .black.opacity(sample.shadowOpacity),
                radius: sample.shadowRadius,
                y: sample.shadowY
            )
    }
}

extension OnboardingHomeScreenMockup {
    fileprivate struct IconLayout: Identifiable {
        let id: String
        let assetName: String
        let center: CGPoint
    }
}
