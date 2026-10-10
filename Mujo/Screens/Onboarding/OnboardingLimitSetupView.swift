import DeviceActivity
import SwiftUI
import UIKit

struct OnboardingLimitSetupView: View {

    enum Step {
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
        _screenTime = ObservedObject(wrappedValue: screenTime)
        _selectedMinutes = State(
            initialValue: usesPreviewData
                ? OnboardingPreviewData.initialLimitMinutes
                : 0
        )
        self.usesPreviewData = usesPreviewData
        self.onCompleted = onCompleted
    }

#if DEBUG
    init(
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
        let calendar = Calendar.autoupdatingCurrent
        let end = calendar.startOfDay(for: .now)
        let start = calendar.date(
            byAdding: .day,
            value: -OnboardingProjectionRules.recentDayCount,
            to: end
        ) ?? end

        return DeviceActivityFilter(
            segment: .daily(
                during: DateInterval(start: start, end: end)
            ),
            users: .all,
            devices: .all
        )
    }

    var body: some View {
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
        .onAppear {
#if DEBUG
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
        VStack(spacing: 0) {
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
        step = .chooseLimit
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
