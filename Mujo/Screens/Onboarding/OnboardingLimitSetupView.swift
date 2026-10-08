import DeviceActivity
import SwiftUI
import UIKit

private enum OnboardingInteractionMetrics {
    static let stepAnimationDuration = 0.3
}

private enum OnboardingPreviewData {
    static let dailyAverageMinutes = 210
    static let initialLimitMinutes = 120
}

private enum OnboardingAssetName {
    static let badgeLight = "Badge_light"
    static let badgeDark = "Badge_dark"
    static let homeScreenWidgetLight = "HomeScreenWidget_light"
    static let homeScreenWidgetDark = "HomeScreenWidget_dark"
    static let launchLogo = "LaunchLogo"
}

private enum OnboardingLayoutMetrics {
    static let topHeadingPadding: CGFloat = 34
    static let savingsReportMinimumHeight: CGFloat = 420
    static let lockScreenAspectRatio: CGFloat = 1.2
    static let homeScreenWidgetMaximumWidth: CGFloat = 360
    static let homeScreenWidgetCornerRadius: CGFloat = 42
    static let badgeMaximumSize: CGFloat = 270
    static let badgeCornerRadius: CGFloat = 32
}

private struct AdaptiveOnboardingStep<Content: View>: View {
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

private enum OnboardingInsightPage: Int, CaseIterable {
    case day
    case week
    case year
}

private struct OnboardingNotificationBanner: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(appIconBackground)
                    .frame(width: 40, height: 40)

                Image(OnboardingAssetName.launchLogo)
                    .resizable()
                    .scaledToFit()
                    .padding(1)
            }
            .frame(width: 48, height: 48)
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("Nothing remains.")
                    .font(.system(
                        size: OnboardingTypography.systemUI,
                        weight: .semibold
                    ))

                Text("You've reached the time you chose for today.")
                    .font(.system(
                        size: OnboardingTypography.systemUI,
                        weight: .regular
                    ))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(notificationTextColor)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(notificationBackground, in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(notificationBorder, lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            Text("now")
                .font(.system(
                    size: 12,
                    weight: .regular
                ))
                .foregroundStyle(notificationTimestampColor)
                .padding(.top, 10)
                .padding(.trailing, 16)
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.16),
            radius: 16,
            y: 8
        )
        .shadow(
            color: Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.16),
            radius: 20,
            y: 8
        )
        .accessibilityElement(children: .combine)
    }

    private var notificationTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var notificationTimestampColor: Color {
        notificationTextColor.opacity(0.56)
    }

    private var notificationBackground: Color {
        MujoTheme.surfaceBackground(for: colorScheme)
    }

    private var notificationBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.16)
            : Color.white.opacity(0.90)
    }

    private var appIconBackground: Color {
        MujoTheme.raisedSurfaceBackground(for: colorScheme)
    }
}

private struct NotificationRequestErrorOverlay: View {
    let tryAgain: () -> Void
    let continueWithoutNotifications: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Notifications couldn’t be enabled.")
                    .font(MujoTheme.boldFont(
                        size: 24,
                        relativeTo: .title2
                    ))

                Text("Please try again.")
                    .font(MujoTheme.mediumFont(size: 17, relativeTo: .body))
                    .padding(.top, 8)

                OnboardingPrimaryButton(action: tryAgain) {
                    Text("Try again")
                }
                .padding(.top, 28)

                OnboardingSecondaryButton(
                    title: "Continue without notifications",
                    action: continueWithoutNotifications
                )
                .padding(.top, 5)
            }
            .foregroundStyle(.tint)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .padding(.horizontal, 26)
        }
        .transition(.opacity)
        .zIndex(10)
    }
}

private struct OnboardingLockScreenMockup: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let remainingText = Text(verbatim: "1:30 remaining")
            .foregroundStyle(widgetEmphasisColor)

        ZStack(alignment: .top) {
            LinearGradient(
                colors: mockupGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                Text("Sat 26  ·  \(remainingText)")
                    .font(.system(
                        size: 23,
                        weight: .semibold,
                        design: .rounded
                    ))
                    .foregroundStyle(clockColor)

                Text("17:11")
                    .font(.system(
                        size: 114,
                        weight: .bold,
                        design: .rounded
                    ))
                    .foregroundStyle(clockColor)
                    .tracking(-2)
                    .padding(.top, -4)

                ZStack {
                    Circle()
                        .stroke(
                            supportingContentColor.opacity(0.35),
                            lineWidth: 2.5
                        )

                    Circle()
                        .trim(from: 0, to: 0.5)
                        .stroke(
                            widgetEmphasisColor,
                            style: StrokeStyle(
                                lineWidth: 2.5,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))

                    Text("1:30")
                        .font(.system(
                            size: 15,
                            weight: .semibold,
                            design: .rounded
                        ))
                        .foregroundStyle(widgetEmphasisColor)
                }
                .frame(width: 58, height: 58)
                .padding(.top, -8)
            }
            .padding(.top, 78)
        }
        .clipShape(
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    bottomLeading: 60,
                    bottomTrailing: 60
                ),
                style: .continuous
            )
        )
        .shadow(
            color: mockupPink.opacity(0.48),
            radius: 22,
            y: 14
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Lock Screen preview showing one hour and thirty minutes remaining"
        )
    }

    private var clockColor: Color {
        mockupForegroundColor.opacity(0.70)
    }

    private var supportingContentColor: Color {
        mockupForegroundColor.opacity(0.60)
    }

    private var widgetEmphasisColor: Color {
        MujoTheme.widgetEmphasis(for: colorScheme)
    }

    private var mockupPink: Color {
        MujoTheme.brandAccent
    }

    private var mockupForegroundColor: Color {
        MujoTheme.surfaceBackground(for: colorScheme)
    }

    private var mockupGradientColors: [Color] {
        MujoTheme.lockScreenMockupBackgroundColors
    }

}

private struct OnboardingSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(MujoTheme.mediumFont(
                size: OnboardingTypography.supporting,
                relativeTo: .body
            ))
            .foregroundStyle(.tint)
            .buttonStyle(.plain)
            .frame(minHeight: 44)
    }
}

private struct OnboardingLimitReachedMark: View {
    var body: some View {
        Image(OnboardingAssetName.launchLogo)
            .resizable()
            .scaledToFit()
            .frame(width: 220, height: 220)
            .shadow(
                color: Color.accentColor.opacity(0.24),
                radius: 18,
                y: 10
            )
            .accessibilityLabel("Mujø")
    }
}

private enum OnboardingWidgetHelp: String, Identifiable {
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

    var steps: [Text] {
        switch self {
        case .lockScreen:
            [
                Text("Touch and hold your Lock Screen, then tap Customize."),
                Text("Choose Lock Screen and tap the widget area below/above the clock."),
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

private struct OnboardingWidgetHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    let help: OnboardingWidgetHelp

    var body: some View {
        ZStack {
            SakuraBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Image(systemName: help.systemImage)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.tint)
                    .frame(width: 72, height: 72)
                    .background(
                        Color.accentColor.opacity(0.08),
                        in: RoundedRectangle(
                            cornerRadius: 22,
                            style: .continuous
                        )
                    )
                    .padding(.top, 42)

                Text(help.title)
                    .font(MujoTheme.boldFont(
                        size: 38,
                        relativeTo: .largeTitle
                    ))
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                VStack(spacing: 24) {
                    ForEach(Array(help.steps.enumerated()), id: \.offset) {
                        index, step in
                        HStack(alignment: .center, spacing: 16) {
                            Text("\(index + 1)")
                                .font(MujoTheme.boldFont(
                                    size: OnboardingTypography.descriptive,
                                    relativeTo: .body
                                ))
                                .foregroundStyle(.tint)
                                .frame(width: 38, height: 38)
                                .overlay {
                                    Circle()
                                        .stroke(
                                            Color.accentColor,
                                            lineWidth: 1.5
                                        )
                                }

                            step
                                .font(MujoTheme.italicFont(
                                    size: OnboardingTypography.descriptive,
                                    relativeTo: .body
                                ))
                                .foregroundStyle(.tint)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 42)

                Spacer(minLength: 24)

                OnboardingPrimaryButton(action: { dismiss() }) {
                    Text("Got it")
                }
                .padding(.horizontal, 34)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct OnboardingInsightsAndLimitReportSection<ReportContent: View>: View {
    let isChoosingLimit: Bool
    let showsHistoryReport: Bool
    private let reportContent: () -> ReportContent

#if DEBUG
    // Temporary A/B diagnostic: keep the Set Limit layout intact while
    // removing DeviceActivityReport from that step's view hierarchy entirely.
    private let bypassesLimitPromptReportForPerformanceTest = true
#else
    private let bypassesLimitPromptReportForPerformanceTest = false
#endif

    init(
        isChoosingLimit: Bool,
        showsHistoryReport: Bool,
        @ViewBuilder reportContent: @escaping () -> ReportContent
    ) {
        self.isChoosingLimit = isChoosingLimit
        self.showsHistoryReport = showsHistoryReport
        self.reportContent = reportContent
    }

    var body: some View {
#if DEBUG
        let _ = PerformanceDiagnostics.throttledLog(
            key: "OnboardingInsightsAndLimitReportSection.body.\(isChoosingLimit)",
            "swiftui-body",
            "report section body; choosingLimit=\(isChoosingLimit), showsHistory=\(showsHistoryReport), bypass=\(bypassesLimitPromptReportForPerformanceTest)"
        )
#endif
        Group {
            if isChoosingLimit {
                Text("Take the first step")
                    .font(MujoTheme.boldFont(size: 40, relativeTo: .largeTitle))
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    "Set the amount of screen time\nyou want to give yourself each day."
                )
                .font(MujoTheme.italicFont(
                    size: OnboardingTypography.descriptive,
                    relativeTo: .body
                ))
                .foregroundStyle(.tint)
                .multilineTextAlignment(.center)
                .padding(.top, 12)

                Spacer(minLength: 12)
            } else {
                Text("Before you\nchoose, know\nwhere you are")
                    .font(MujoTheme.boldFont(
                        size: 40,
                        relativeTo: .largeTitle
                    ))
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(2)
                    .padding(
                        .top,
                        OnboardingLayoutMetrics.topHeadingPadding
                    )

                Spacer(minLength: 32)
            }

            if showsHistoryReport,
               isChoosingLimit,
               bypassesLimitPromptReportForPerformanceTest {
                Color.clear
                    .frame(height: 72)
                    .padding(.horizontal, 32)
                    .onAppear {
#if DEBUG
                        PerformanceDiagnostics.log(
                            "onboarding",
                            "Set Limit report host bypassed; diagnostic placeholder appeared"
                        )
#endif
                    }
            } else if showsHistoryReport {
                reportContent()
                    .frame(height: isChoosingLimit ? 72 : nil)
                    .frame(maxHeight: isChoosingLimit ? nil : 460)
                    .layoutPriority(1)
                    .padding(.horizontal, isChoosingLimit ? 32 : 0)
                    .allowsHitTesting(!isChoosingLimit)
            }
        }
    }
}

private struct OnboardingLimitSelectionSection: View {
    @State private var selectedMinutes: Int
    @State private var isSaving = false

    let onSave: (Int) async -> Bool

    init(
        initialMinutes: Int,
        onSave: @escaping (Int) async -> Bool
    ) {
        _selectedMinutes = State(initialValue: initialMinutes)
        self.onSave = onSave
    }

    var body: some View {
#if DEBUG
        let _ = PerformanceDiagnostics.throttledLog(
            key: "OnboardingLimitSelectionSection.body",
            minimumInterval: 0.10,
            "swiftui-body",
            "limit selection body; minutes=\(selectedMinutes), saving=\(isSaving)"
        )
#endif
        Group {
            Text(selectedTime)
                .font(MujoTheme.boldFont(
                    size: 88,
                    relativeTo: .largeTitle
                ))
                .monospacedDigit()
                .foregroundStyle(.tint)
                .contentTransition(.numericText())

            Text("Daily limit")
                .font(MujoTheme.italicFont(
                    size: OnboardingTypography.descriptive,
                    relativeTo: .subheadline
                ))
                .foregroundStyle(.tint)
                .padding(.top, -6)

            TimeDial(
                minutes: $selectedMinutes,
                windStrength: .constant(0),
                allowsEmptySelection: true,
                showsValue: false,
                onValueChange: { _ in },
                onCommit: { _ in }
            )
            .padding(.top, 24)

            Spacer(minLength: 22)

            OnboardingPrimaryButton(
                isDisabled: selectedMinutes == 0 || isSaving,
                action: saveLimit
            ) {
                if isSaving {
                    ProgressView()
                } else {
                    Text("Set limit")
                }
            }
            .padding(.horizontal, 34)

            Text("You can always change your limit later.")
                .font(MujoTheme.italicFont(
                    size: OnboardingTypography.supporting,
                    relativeTo: .subheadline
                ))
                .foregroundStyle(.tint)
                .padding(.top, 7)
                .opacity(selectedMinutes == 0 ? 0 : 1)
                .accessibilityHidden(selectedMinutes == 0)
        }
        .onAppear {
#if DEBUG
            PerformanceDiagnostics.markPhase("onboarding.chooseLimit.controls.appeared")
            PerformanceDiagnostics.log(
                "onboarding",
                "limit controls appeared; minutes=\(selectedMinutes)"
            )
#endif
        }
        .onChange(of: selectedMinutes) { oldValue, newValue in
#if DEBUG
            PerformanceDiagnostics.log(
                "onboarding",
                "local selected minutes changed \(oldValue) -> \(newValue)"
            )
#endif
        }
    }

    private var selectedTime: String {
        OnboardingDurationFormatter.string(
            minutes: selectedMinutes,
            emptyPlaceholder: "–"
        )
    }

    private func saveLimit() {
        guard selectedMinutes > 0, !isSaving else { return }

        isSaving = true
        let minutes = selectedMinutes
        Task {
            if !(await onSave(minutes)) {
                isSaving = false
            }
        }
    }
}

struct OnboardingLimitSetupView: View {

    fileprivate enum Step {
        case insights
        case chooseLimit
        case savings
        case limitReached
        case notifications
        case lockScreenWidget
        case homeScreenWidget
    }

    @ObservedObject var screenTime: ScreenTimeManager
    @Environment(\.colorScheme) private var colorScheme
    let onCompleted: () -> Void
    private let usesPreviewData: Bool

    @State private var step: Step = .insights
    @State private var insightPage: OnboardingInsightPage = .day
    @State private var selectedMinutes = 0
    @State private var showsHistoryReports = true
    @State private var isRequestingNotifications = false
    @State private var isShowingNotificationRequestError = false
    @State private var isShowingNotificationDenialAlert = false
    @State private var widgetHelp: OnboardingWidgetHelp?
    @StateObject private var notificationAuthorization = NotificationAuthorization()
    @AppStorage("wasNotificationPromptShown")
    private var wasNotificationPromptShown = false

    init(
        screenTime: ScreenTimeManager,
        usesPreviewData: Bool = false,
        onCompleted: @escaping () -> Void
    ) {
#if DEBUG
        let startedAt = PerformanceDiagnostics.now
#endif
        _screenTime = ObservedObject(wrappedValue: screenTime)
        _selectedMinutes = State(
            initialValue: usesPreviewData
                ? OnboardingPreviewData.initialLimitMinutes
                : 0
        )
        self.usesPreviewData = usesPreviewData
        self.onCompleted = onCompleted
#if DEBUG
        PerformanceDiagnostics.log(
            "onboarding",
            "OnboardingLimitSetupView initialized in \(PerformanceDiagnostics.elapsedMilliseconds(since: startedAt)) ms; preview=\(usesPreviewData)"
        )
#endif
    }

#if DEBUG
    fileprivate init(
        previewStep: Step,
        insightPage: OnboardingInsightPage = .day
    ) {
        _screenTime = ObservedObject(wrappedValue: ScreenTimeManager())
        _step = State(initialValue: previewStep)
        _insightPage = State(initialValue: insightPage)
        _selectedMinutes = State(
            initialValue: OnboardingPreviewData.initialLimitMinutes
        )
        usesPreviewData = true
        onCompleted = {}
    }
#endif

    private var sevenDayReportFilter: DeviceActivityFilter {
#if DEBUG
        let startedAt = PerformanceDiagnostics.now
#endif
        let calendar = Calendar.autoupdatingCurrent
        let end = calendar.startOfDay(for: .now)
        let start = calendar.date(
            byAdding: .day,
            value: -OnboardingProjectionRules.recentDayCount,
            to: end
        ) ?? end

        let filter = DeviceActivityFilter(
            segment: .daily(
                during: DateInterval(start: start, end: end)
            ),
            users: .all,
            devices: .all
        )
#if DEBUG
        PerformanceDiagnostics.log(
            "onboarding",
            "seven-day report filter created in \(PerformanceDiagnostics.elapsedMilliseconds(since: startedAt)) ms; start=\(start), end=\(end)"
        )
#endif
        return filter
    }

    var body: some View {
#if DEBUG
        let _ = PerformanceDiagnostics.throttledLog(
            key: "OnboardingLimitSetupView.body.\(String(describing: step))",
            minimumInterval: 0.10,
            "swiftui-body",
            "OnboardingLimitSetupView body; step=\(String(describing: step)), insightPage=\(String(describing: insightPage)), history=\(showsHistoryReports)"
        )
#endif
        ZStack {
            OnboardingBackground()

            // Insights and limit selection share one persistent report so the
            // already calculated average is not queried for a second time.
            switch step {
            case .insights, .chooseLimit:
                insightsAndLimitStep.transition(.identity)
            case .savings: savingsStep.transition(.identity)
            case .limitReached: limitReachedStep
            case .notifications: notificationsStep
            case .lockScreenWidget: lockScreenWidgetStep
            case .homeScreenWidget: homeScreenWidgetStep
            }

            if isShowingNotificationRequestError {
                NotificationRequestErrorOverlay(
                    tryAgain: {
                        isShowingNotificationRequestError = false
                        enableNotifications()
                    },
                    continueWithoutNotifications: {
                        isShowingNotificationRequestError = false
                        finishNotificationStep()
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: step) { oldStep, newStep in
#if DEBUG
            PerformanceDiagnostics.markPhase(
                "onboarding.step.\(String(describing: newStep))"
            )
            PerformanceDiagnostics.log(
                "onboarding",
                "step changed \(String(describing: oldStep)) -> \(String(describing: newStep))"
            )
#endif
        }
        .onAppear {
#if DEBUG
            PerformanceDiagnostics.markPhase(
                "onboarding.appeared.\(String(describing: step))"
            )
            PerformanceDiagnostics.log(
                "onboarding",
                "OnboardingLimitSetupView appeared; step=\(String(describing: step))"
            )
            if !usesPreviewData,
               DiagnosticsScenarioStore.consumeNoHistoryOnboarding() {
                showsHistoryReports = false
                step = .chooseLimit
            }
#endif
        }
        .alert(
            "Are you sure you don’t want notifications?",
            isPresented: $isShowingNotificationDenialAlert
        ) {
            Button("Open Settings") {
                openNotificationSettings()
            }
            Button("Continue without notifications", role: .cancel) {
                finishNotificationStep()
            }
        } message: {
            Text(
                "You won’t receive notifications when you approach or reach your daily screen time limit."
            )
        }
        .sheet(item: $widgetHelp) { help in
            OnboardingWidgetHelpSheet(help: help)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var insightsAndLimitStep: some View {
#if DEBUG
        let _ = PerformanceDiagnostics.throttledLog(
            key: "OnboardingLimitSetupView.insightsAndLimitStep.\(String(describing: step))",
            minimumInterval: 0.10,
            "swiftui-body",
            "insightsAndLimitStep evaluated; step=\(String(describing: step))"
        )
#endif
        return VStack(spacing: 0) {
            OnboardingInsightsAndLimitReportSection(
                isChoosingLimit: step == .chooseLimit,
                showsHistoryReport: showsHistoryReports
            ) {
                report(
                    context: .mujoInsightsCarousel,
                    filter: sevenDayReportFilter,
                    loadingMessage: step == .insights
                        ? "Loading your insights…"
                        : "Loading your average time…"
                )
            }

            if step == .insights {
                Spacer(minLength: 32)

                OnboardingPrimaryButton(action: advanceInsight) {
                    Text("Continue")
                }
                .padding(.horizontal, 34)
            } else {
                Spacer(minLength: 12)

                OnboardingLimitSelectionSection(
                    initialMinutes: selectedMinutes,
                    onSave: saveLimit(minutes:)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, step == .chooseLimit
            ? OnboardingLayoutMetrics.topHeadingPadding
            : 0)
        .padding(.bottom, step == .insights ? 34 : 10)
    }

    private func advanceInsight() {
#if DEBUG
        let startedAt = PerformanceDiagnostics.now
        PerformanceDiagnostics.markPhase("onboarding.insights.continue-tapped")
        PerformanceDiagnostics.log(
            "onboarding",
            "Continue tapped; switching insights -> chooseLimit"
        )
#endif
        step = .chooseLimit
#if DEBUG
        PerformanceDiagnostics.log(
            "onboarding",
            "step assignment finished in \(PerformanceDiagnostics.elapsedMilliseconds(since: startedAt)) ms"
        )
        PerformanceDiagnostics.mainQueueProbe(
            "onboarding",
            "after chooseLimit step assignment",
            startedAt: startedAt
        )
#endif
    }

    private var savingsStep: some View {
        AdaptiveOnboardingStep {
            VStack(spacing: 0) {
                savingsHeader

                report(
                    context: .mujoSavingsCarousel,
                    filter: sevenDayReportFilter
                )
                .frame(minHeight: OnboardingLayoutMetrics.savingsReportMinimumHeight)

                Spacer(minLength: 32)

                OnboardingPrimaryButton(action: advanceSavings) {
                    Text("Continue")
                }
                .padding(.horizontal, 34)

            }
            .padding(.bottom, 34)
        }
    }

    private var savingsHeader: some View {
        VStack(spacing: 0) {
            Text("Your new limit\nis set!")
                .font(MujoTheme.boldFont(
                    size: 40,
                    relativeTo: .largeTitle
                ))
                .foregroundStyle(.tint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(
                    .top,
                    OnboardingLayoutMetrics.topHeadingPadding
                )

            let limit = Text(verbatim: selectedTime)
                .font(MujoTheme.semiboldItalicFont(
                    size: OnboardingTypography.descriptive,
                    relativeTo: .body
                ))

            Text("Your daily limit: \(limit)")
                .font(MujoTheme.italicFont(
                    size: OnboardingTypography.descriptive,
                    relativeTo: .body
                ))
                .padding(.top, 16)
                .foregroundStyle(.tint)
                .multilineTextAlignment(.center)
        }
    }

    private var notificationsStep: some View {
        AdaptiveOnboardingStep {
            VStack(spacing: 0) {
                OnboardingNotificationBanner()
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                Text("Stay aware of\nyour time")
                    .font(MujoTheme.boldFont(
                        size: 40,
                        relativeTo: .largeTitle
                    ))
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 28)

                Text("Without constantly checking.")
                    .font(MujoTheme.italicFont(
                        size: OnboardingTypography.descriptive,
                        relativeTo: .subheadline
                    ))
                    .foregroundStyle(.tint)
                    .padding(.top, 8)

                Spacer(minLength: 8)

                Image(badgeAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: OnboardingLayoutMetrics.badgeMaximumSize,
                        maxHeight: OnboardingLayoutMetrics.badgeMaximumSize
                    )
                    .clipShape(.rect(
                        cornerRadius: OnboardingLayoutMetrics.badgeCornerRadius
                    ))
                    .shadow(
                        color: Color.accentColor.opacity(0.4),
                        radius: 18,
                        y: 10
                    )
                    .accessibilityLabel("Mujø badge preview")

                Text("See your remaining minutes\non the app icon.")
                    .font(MujoTheme.italicFont(
                        size: OnboardingTypography.descriptive,
                        relativeTo: .subheadline
                    ))
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)

                Spacer(minLength: 8)

                OnboardingPrimaryButton(
                    isDisabled: isRequestingNotifications,
                    action: enableNotifications
                ) {
                    if isRequestingNotifications {
                        ProgressView()
                    } else {
                        Text("Continue")
                    }
                }
                .padding(.horizontal, 34)
            }
            .padding(.bottom, 34)
        }
    }

    private var limitReachedStep: some View {
        AdaptiveOnboardingStep {
            VStack(spacing: 0) {
                Text("What happens\nwhen you reach\nyour limit?")
                    .font(MujoTheme.boldFont(
                        size: 40,
                        relativeTo: .largeTitle
                    ))
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)
                    .padding(.top, OnboardingLayoutMetrics.topHeadingPadding)

                Spacer()

                OnboardingLimitReachedMark()

                Spacer()

                Text(
                    "Nothing gets locked. Mujø sends you a gentle reminder - then leaves the choice with you."
                )
                .font(MujoTheme.italicFont(
                    size: OnboardingTypography.descriptive,
                    relativeTo: .body
                ))
                .foregroundStyle(.tint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 30)
                .padding(.bottom, 32)

//                HStack(alignment: .center, spacing: 16) {
//                    Image(systemName: "bell.badge")
//                        .font(.system(size: 20, weight: .semibold))
//                        .foregroundStyle(.tint)
//
//                    Text(
//                        "Next, Mujø will ask to send notifications. Without them, it can’t tell you when you reach your limit."
//                    )
//                    .font(MujoTheme.mediumFont(
//                        size: OnboardingTypography.supporting,
//                        relativeTo: .subheadline
//                    ))
//                    .foregroundStyle(.tint)
//                    .fixedSize(horizontal: false, vertical: true)
//                }
//                .padding(.horizontal, 18)
//                .padding(.vertical, 16)
//                .glassEffect(.clear, in: .rect(cornerRadius: 24))
//                .padding(.horizontal, 28)
//                .padding(.top, 28)

//                Spacer(minLength: 28)

                OnboardingPrimaryButton(action: {
                    step = .notifications
                }) {
                    Text("Got it")
                }
                .padding(.horizontal, 34)
            }
            .padding(.bottom, 34)
        }
    }

    private var lockScreenWidgetStep: some View {
        widgetStep(
            title: "Your time on your\nLock Screen",
            subtitle: "See what’s remaining\nwithout unlocking your phone",
            imageFirst: true,
            help: .lockScreen,
            onContinue: { step = .homeScreenWidget }
        )
    }

    private var homeScreenWidgetStep: some View {
        widgetStep(
            title: "Your time at a\nglance",
            subtitle: "See what’s remaining right on your\nhome screen without opening Mujø",
            imageFirst: false,
            help: .homeScreen,
            onContinue: onCompleted
        )
    }

    private func widgetStep(
        title: String,
        subtitle: String,
        imageFirst: Bool,
        help: OnboardingWidgetHelp,
        onContinue: @escaping () -> Void
    ) -> some View {
        AdaptiveOnboardingStep {
            VStack(spacing: 0) {
                if imageFirst {
                    OnboardingLockScreenMockup()
                        .aspectRatio(
                            OnboardingLayoutMetrics.lockScreenAspectRatio,
                            contentMode: .fit
                        )
                }

                if imageFirst {
                    Spacer(minLength: 20)
                }

                Text(title)
                    .font(MujoTheme.boldFont(
                        size: 40,
                        relativeTo: .largeTitle
                    ))
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)
                    .padding(
                        .top,
                        imageFirst
                            ? 0
                            : OnboardingLayoutMetrics.topHeadingPadding
                    )

                Text(subtitle)
                    .font(MujoTheme.italicFont(
                        size: OnboardingTypography.descriptive,
                        relativeTo: .subheadline
                    ))
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)

                if !imageFirst {
                    Image(homeScreenWidgetAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            maxWidth: OnboardingLayoutMetrics
                                .homeScreenWidgetMaximumWidth
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
                        .accessibilityLabel("Mujø Home Screen widget preview")
                        .padding(.top, 24)
                }

                Spacer(minLength: 20)

                OnboardingPrimaryButton(action: onContinue) {
                    Text("Got it")
                }
                .padding(.horizontal, 34)

                OnboardingSecondaryButton(
                    title: "Show me how to add it ›",
                    action: { widgetHelp = help }
                )
                .padding(.top, 5)
            }
            .padding(.bottom, 16)
        }
        .scrollDisabled(!imageFirst)
        .ignoresSafeArea(edges: imageFirst ? .top : [])
    }

    private func enableNotifications() {
        guard !isRequestingNotifications else { return }

        if usesPreviewData {
            finishNotificationStep()
            return
        }

        isRequestingNotifications = true

        Task {
            let outcome = await notificationAuthorization
                .requestAuthorization()
            isRequestingNotifications = false
            switch outcome {
            case .authorized:
                finishNotificationStep()
            case .denied:
                isShowingNotificationDenialAlert = true
            case .failed:
                isShowingNotificationRequestError = true
            }
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(
            string: UIApplication.openNotificationSettingsURLString
        ) else {
            isShowingNotificationRequestError = true
            return
        }

        UIApplication.shared.open(url) { opened in
            guard !opened else { return }
            Task { @MainActor in
                isShowingNotificationRequestError = true
            }
        }
    }

    private func finishNotificationStep() {
        if !usesPreviewData {
            wasNotificationPromptShown = true
        }
        withAnimation(.easeInOut(
            duration: OnboardingInteractionMetrics.stepAnimationDuration
        )) {
            step = .lockScreenWidget
        }
    }

    @ViewBuilder
    private func report(
        context: DeviceActivityReport.Context,
        filter: DeviceActivityFilter,
        loadingMessage: String? = nil
    ) -> some View {
        if usesPreviewData {
            previewReport(context: context)
        } else {
            ZStack {
                ScreenTimeReportLoadingView(
                    message: loadingMessage
                        ?? defaultLoadingMessage(for: context)
                )

                ScreenTimeReportView(context: context, filter: filter)
                    .equatable()
                    .id(context.rawValue)
                    .accessibilityElement(children: .contain)
            }
        }
    }

    private func defaultLoadingMessage(
        for context: DeviceActivityReport.Context
    ) -> String {
        if context == .mujoInsightsCarousel {
            return "Loading your insights…"
        }
        if context == .mujoSavingsCarousel {
            return "Loading your savings…"
        }
        return "Loading your average time…"
    }

    @ViewBuilder
    private func previewReport(
        context: DeviceActivityReport.Context
    ) -> some View {
        if context == .mujoInsightsCarousel {
            if step == .chooseLimit {
                previewLimitPrompt
            } else {
                VStack(spacing: 0) {
                    previewInsightCard(page: insightPage)
                        .frame(maxHeight: .infinity)

                    HStack(spacing: 16) {
                        ForEach(
                            OnboardingInsightPage.allCases,
                            id: \.self
                        ) { page in
                            Circle()
                                .fill(
                                    page == insightPage
                                        ? Color.accentColor
                                        : Color.accentColor.opacity(
                                            colorScheme == .dark ? 0.30 : 0.36
                                        )
                                )
                                .frame(width: 10, height: 10)
                        }
                    }
                    .accessibilityHidden(true)
                }
                .padding(.top, 22)
            }
        } else if context == .mujoDailyAverage {
            previewInsightCard(page: .day)
        } else if context == .mujoWeeklyTotal {
            previewInsightCard(page: .week)
        } else if context == .mujoYearlyTotal {
            previewInsightCard(page: .year)
        } else if context == .mujoSavingsCarousel {
            VStack(spacing: 0) {
                previewSavingsReport(page: 0)
                    .frame(maxHeight: .infinity)

                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { page in
                        Circle()
                            .fill(
                                page == 0
                                    ? Color.accentColor
                                    : Color.accentColor.opacity(
                                        colorScheme == .dark ? 0.30 : 0.36
                                    )
                            )
                            .frame(width: 10, height: 10)
                    }
                }
                .accessibilityHidden(true)
            }
            .padding(.top, 22)
        } else if context == .mujoDailySavings {
            previewSavingsReport(page: 0)
        } else if context == .mujoWeeklySavings {
            previewSavingsReport(page: 1)
        } else if context == .mujoAnnualSavings {
            previewSavingsReport(page: 2)
        }
    }

    private var previewLimitPrompt: some View {
        let average = Text(verbatim: "3h 30m")
            .font(MujoTheme.semiboldItalicFont(
                size: OnboardingTypography.descriptive,
                relativeTo: .body
            ))
        let suggestion = Text(verbatim: "2h 00m")
            .font(MujoTheme.semiboldItalicFont(
                size: OnboardingTypography.descriptive,
                relativeTo: .body
            ))

        return Text(
            "Your average \(average) a day.\nTry starting with \(suggestion)."
        )
        .font(MujoTheme.italicFont(
            size: OnboardingTypography.descriptive,
            relativeTo: .body
        ))
        .foregroundStyle(.tint)
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private func previewInsightCard(page: OnboardingInsightPage) -> some View {
        switch page {
        case .day:
            OnboardingInsightCard(
                value: "3h\n30m",
                primaryCaption: .init("your ", emphasis: "daily average"),
                secondaryCaption: .init(
                    "over the ",
                    emphasis: "last 7 days"
                )
            )
        case .week:
            OnboardingInsightCard(
                value: "24h\n30m",
                primaryCaption: .init("your ", emphasis: "actual screen time"),
                secondaryCaption: .init(
                    "over the ",
                    emphasis: "last 7 days"
                )
            )
        case .year:
            OnboardingInsightCard(
                value: "53d\n5h",
                primaryCaption: .init("at this pace,"),
                secondaryCaption: .init("in one ", emphasis: "year")
            )
        }
    }

    private func previewSavingsReport(page: Int) -> some View {
        let baselineMinutes = OnboardingPreviewData.dailyAverageMinutes
            * OnboardingProjectionRules.annualDayCount
        let limitedMinutes = min(
            baselineMinutes,
            selectedMinutes * OnboardingProjectionRules.annualDayCount
        )
        let reclaimedMinutes = max(0, baselineMinutes - limitedMinutes)

        return OnboardingSavingsCard(
            annualSavingsMinutes: reclaimedMinutes,
            page: page
        )
    }

    private var badgeAssetName: String {
        colorScheme == .dark
            ? OnboardingAssetName.badgeDark
            : OnboardingAssetName.badgeLight
    }

    private var homeScreenWidgetAssetName: String {
        colorScheme == .dark
            ? OnboardingAssetName.homeScreenWidgetDark
            : OnboardingAssetName.homeScreenWidgetLight
    }

    private var selectedTime: String {
        OnboardingDurationFormatter.string(
            minutes: selectedMinutes,
            emptyPlaceholder: "–"
        )
    }

    private func advanceSavings() {
        withAnimation(.easeInOut(
            duration: OnboardingInteractionMetrics.stepAnimationDuration
        )) {
            step = .limitReached
        }
    }

    private func saveLimit(minutes: Int) async -> Bool {
        guard minutes > 0 else { return false }

        if usesPreviewData {
            selectedMinutes = minutes
            withAnimation(.easeInOut(
                duration: OnboardingInteractionMetrics.stepAnimationDuration
            )) {
                step = showsHistoryReports ? .savings : .limitReached
            }
            return true
        }

        await screenTime.setDailyLimit(minutes: minutes)

        guard screenTime.isAuthorized,
              screenTime.errorMessage == nil
        else { return false }

        selectedMinutes = minutes
        withAnimation(.easeInOut(
            duration: OnboardingInteractionMetrics.stepAnimationDuration
        )) {
            step = showsHistoryReports ? .savings : .limitReached
        }
        return true
    }
}

#if DEBUG
private struct OnboardingScreenPreview: View {
    let step: OnboardingLimitSetupView.Step
    var insightPage: OnboardingInsightPage = .day

    var body: some View {
        ZStack {
            OnboardingBackground()
            OnboardingLimitSetupView(
                previewStep: step,
                insightPage: insightPage
            )
        }
    }
}

#Preview("01 · Average day") {
    OnboardingScreenPreview(step: .insights, insightPage: .day)
}

#Preview("02 · Week") {
    OnboardingScreenPreview(step: .insights, insightPage: .week)
}

#Preview("03 · Year") {
    OnboardingScreenPreview(step: .insights, insightPage: .year)
}

#Preview("04 · Choose limit") {
    OnboardingScreenPreview(step: .chooseLimit)
}

#Preview("05 · Annual savings") {
    OnboardingScreenPreview(step: .savings)
}

#Preview("06 · Limit reached") {
    OnboardingScreenPreview(step: .limitReached)
}

#Preview("07 · Notifications") {
    OnboardingScreenPreview(step: .notifications)
}

#Preview("08 · Lock Screen widget") {
    OnboardingScreenPreview(step: .lockScreenWidget)
}

#Preview("09 · Home Screen widget") {
    OnboardingScreenPreview(step: .homeScreenWidget)
}
#endif
