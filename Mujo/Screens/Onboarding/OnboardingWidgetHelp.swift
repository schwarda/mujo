import SwiftUI

enum OnboardingWidgetHelp: String, Identifiable {
    case lockScreen
    case homeScreen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lockScreen: "Add it to your\nLock Screen"
        case .homeScreen: "Add it to your\nHome Screen"
        }
    }

    var systemImage: String {
        switch self {
        case .lockScreen: "lock.rectangle.stack.fill"
        case .homeScreen: "rectangle.grid.2x2.fill"
        }
    }

    var videoResourceName: String {
        switch self {
        case .lockScreen: "lock_screen"
        case .homeScreen: "home_screen"
        }
    }

    var videoSourceSize: CGSize { CGSize(width: 1080, height: 1920) }

    // Visible phone bounds in the supplied recordings; omit the baked-in side bars.
    var videoContentBounds: CGRect {
        switch self {
        case .lockScreen: CGRect(x: 99, y: 0, width: 882, height: 1920)
        case .homeScreen: CGRect(x: 102, y: 0, width: 883, height: 1920)
        }
    }

    var videoAspectRatio: CGFloat {
        videoContentBounds.width / videoContentBounds.height
    }

    // Temporary cue times in seconds from the beginning of each video.
    // Adjust these values when the final timing is approved.
    var stepStartTimes: [TimeInterval] {
        switch self {
        case .lockScreen: [0, 3, 8]
        case .homeScreen: [0, 3, 6]
        }
    }

    func stepIndex(at playbackTime: TimeInterval) -> Int {
        stepStartTimes.lastIndex(where: { playbackTime >= $0 }) ?? 0
    }

    var steps: [Text] {
        switch self {
        case .lockScreen:
            [
                Text("Touch and hold your Lock Screen, then tap Customize."),
                Text("Tap the widget area below or above the clock."),
                Text("Find Mujø in the widget list and tap the widget to add it.")
            ]
        case .homeScreen:
            [
                Text("Touch and hold an empty area of your Home Screen."),
                Text(
                    "Tap Edit \(Image(systemName: "paintbrush.fill")), then tap Add Widget."
                ),
                Text("Find Mujø, choose a widget, and tap Add Widget.")
            ]
        }
    }
}

#if DEBUG
private struct OnboardingWidgetHelpSheetPreview: View {
    let help: OnboardingWidgetHelp
    @State private var isPresented = true

    var body: some View {
        ZStack {
            SakuraBackground().ignoresSafeArea()

            OnboardingPrimaryButton(action: { isPresented = true }) {
                Text("Show tutorial")
            }
            .padding(.horizontal, 34)
        }
        .sheet(isPresented: $isPresented) {
            OnboardingWidgetHelpSheet(help: help)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview("Lock Screen · Video tutorial") {
    OnboardingWidgetHelpSheetPreview(help: .lockScreen)
}

#Preview("Home Screen · Video tutorial") {
    OnboardingWidgetHelpSheetPreview(help: .homeScreen)
}
#endif

struct OnboardingWidgetHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var playback = OnboardingWidgetTutorialPlayback()

    let help: OnboardingWidgetHelp

    var body: some View {
        ZStack {
            SakuraBackground()
                .ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView {
                    OnboardingWidgetTutorialLayout(
                        aspectRatio: help.videoAspectRatio,
                        availableHeight: max(0, geometry.size.height - 52)
                    ) {
                        Text(help.title)
                            .font(MujoTheme.boldFont(
                                size: 30,
                                relativeTo: .largeTitle
                            ))
                            .foregroundStyle(.tint)
                            .multilineTextAlignment(.center)

                        tutorialVideo
                            .accessibilityHidden(true)

                        currentStep
                    }
                    .padding(.horizontal, 34)
                    .padding(.top, 32)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OnboardingPrimaryButton(action: { dismiss() }) {
                Text("Got it")
            }
            .padding(.horizontal, 34)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .onAppear {
            playback.start(resourceName: help.videoResourceName)
        }
        .onChange(of: help) { _, newHelp in
            playback.start(resourceName: newHelp.videoResourceName)
        }
        .onDisappear {
            playback.stop()
        }
        .onChange(of: scenePhase) { _, phase in
            playback.setActive(phase == .active)
        }
    }

    private var tutorialVideo: some View {
        GeometryReader { geometry in
            let contentBounds = help.videoContentBounds
            let scale = geometry.size.width / contentBounds.width
            // Both large-sheet videos measure about 210.7 pt wide on iPhone 17 Pro
            // at the default text size, where the approved corner radius is 34 pt.
            let referenceVideoWidth: CGFloat = 210.7
            let cornerRadius = 34 * geometry.size.width / referenceVideoWidth

            OnboardingWidgetTutorialVideo(player: playback.player)
                .frame(
                    width: help.videoSourceSize.width * scale,
                    height: help.videoSourceSize.height * scale
                )
                .offset(
                    x: -contentBounds.minX * scale,
                    y: -contentBounds.minY * scale
                )
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .topLeading
                )
                .background(.black)
                .clipShape(RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                ))
        }
    }

    private var currentStep: some View {
        let currentIndex = help.stepIndex(at: playback.elapsedTime)

        return ZStack(alignment: .leading) {
            // Reserve room for the longest step so cue changes do not move the video.
            ForEach(Array(help.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .center, spacing: 16) {
                    Text("\(index + 1)")
                        .font(MujoTheme.boldFont(
                            size: OnboardingTypography.descriptive,
                            relativeTo: .body
                        ))
                        .frame(width: 38, height: 38)
                        .overlay {
                            Circle().stroke(Color.accentColor, lineWidth: 1.5)
                        }

                    step
                        .font(MujoTheme.italicFont(
                            size: OnboardingTypography.descriptive,
                            relativeTo: .body
                        ))
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .foregroundStyle(.tint)
                .opacity(index == currentIndex ? 1 : 0)
                .accessibilityHidden(index != currentIndex)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("widgetTutorialStep\(index + 1)")
            }
        }
    }
}

/// Gives the video the space left after measuring the title and every step.
private struct OnboardingWidgetTutorialLayout: Layout {
    let aspectRatio: CGFloat
    let availableHeight: CGFloat
    private let spacing: CGFloat = 20

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = max(0, proposal.width ?? 0)
        let sizes = contentSizes(width: width, subviews: subviews)
        return CGSize(
            width: width,
            height: sizes.title.height + sizes.video.height + sizes.step.height + spacing * 2
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let sizes = contentSizes(width: bounds.width, subviews: subviews)
        let titleY = bounds.minY
        let videoY = titleY + sizes.title.height + spacing
        let stepY = videoY + sizes.video.height + spacing

        subviews[0].place(
            at: CGPoint(x: bounds.midX, y: titleY),
            anchor: .top,
            proposal: ProposedViewSize(width: bounds.width, height: sizes.title.height)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.midX, y: videoY),
            anchor: .top,
            proposal: ProposedViewSize(sizes.video)
        )
        subviews[2].place(
            at: CGPoint(x: bounds.midX, y: stepY),
            anchor: .top,
            proposal: ProposedViewSize(width: bounds.width, height: sizes.step.height)
        )
    }

    private func contentSizes(
        width: CGFloat,
        subviews: Subviews
    ) -> (title: CGSize, video: CGSize, step: CGSize) {
        let textProposal = ProposedViewSize(width: width, height: nil)
        let title = subviews[0].sizeThatFits(textProposal)
        let step = subviews[2].sizeThatFits(textProposal)
        let remainingHeight = availableHeight - title.height - step.height - spacing * 2
        // Keep the demonstration visible at large text sizes; the sheet can scroll.
        let videoHeight = min(max(160, remainingHeight), width / aspectRatio)
        let video = CGSize(width: videoHeight * aspectRatio, height: videoHeight)
        return (title, video, step)
    }
}
