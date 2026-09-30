import DeviceActivity
import SwiftUI

private enum OnboardingInteractionMetrics {
    static let pageAnimationDuration = 0.35
    static let stepAnimationDuration = 0.3
    static let edgeDragResistance = 0.22
    static let minimumDragDistance: CGFloat = 12
    static let pageChangeThreshold: CGFloat = 60
    static let reportPreloadDelay = Duration.milliseconds(350)
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
    static let insightContentVerticalOffset: CGFloat = -18
    static let limitReportMinimumHeight: CGFloat = 150
    static let limitReportMaximumHeight: CGFloat = 210
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

private struct OnboardingInitialReport: View {
    let context: DeviceActivityReport.Context
    let filter: DeviceActivityFilter
    @State private var showsLoader = true

    var body: some View {
        ZStack {
            DeviceActivityReport(context, filter: filter)
                .accessibilityElement(children: .contain)

            if showsLoader {
                ProgressView()
                    .controlSize(.large)
                    .tint(.accentColor)
                    .accessibilityLabel("Loading Screen Time")
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                showsLoader = false
            }
        }
    }
}

private enum OnboardingInsightPage: Int, CaseIterable {
    case day
    case week
    case year

    var context: DeviceActivityReport.Context {
        switch self {
        case .day: .mujoDailyAverage
        case .week: .mujoWeeklyTotal
        case .year: .mujoYearlyTotal
        }
    }
}

private enum OnboardingSavingsPage: Int, CaseIterable {
    case day
    case week
    case year

    var context: DeviceActivityReport.Context {
        switch self {
        case .day: .mujoDailySavings
        case .week: .mujoWeeklySavings
        case .year: .mujoAnnualSavings
        }
    }
}

private struct OnboardingCardsPager<
    Page: Hashable,
    HeaderContent: View,
    CardContent: View
>: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selection: Page
    let pages: [Page]
    let contentTopPadding: CGFloat
    let buttonSpacing: CGFloat
    let bottomPadding: CGFloat
    let onContinue: () -> Void
    let headerContent: () -> HeaderContent
    let cardContent: (Page) -> CardContent
    @State private var dragOffset: CGFloat = 0

    init(
        selection: Binding<Page>,
        pages: [Page],
        contentTopPadding: CGFloat,
        buttonSpacing: CGFloat,
        bottomPadding: CGFloat,
        onContinue: @escaping () -> Void,
        @ViewBuilder headerContent: @escaping () -> HeaderContent,
        @ViewBuilder cardContent: @escaping (Page) -> CardContent
    ) {
        _selection = selection
        self.pages = pages
        self.contentTopPadding = contentTopPadding
        self.buttonSpacing = buttonSpacing
        self.bottomPadding = bottomPadding
        self.onContinue = onContinue
        self.headerContent = headerContent
        self.cardContent = cardContent
    }

    var body: some View {
        VStack(spacing: 0) {
            headerContent()

            GeometryReader { geometry in
                ZStack {
                    HStack(spacing: 0) {
                        ForEach(pages, id: \.self) { page in
                            cardContent(page)
                                .frame(width: geometry.size.width)
                        }
                    }
                    .offset(
                        x: -CGFloat(selectionIndex)
                            * geometry.size.width
                            + resistedDragOffset
                    )
                    .animation(
                        .easeInOut(
                            duration: OnboardingInteractionMetrics
                                .pageAnimationDuration
                        ),
                        value: selection
                    )

                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .gesture(pageDragGesture)
                }
            }
            .frame(maxHeight: .infinity)
            .layoutPriority(1)
            .padding(.top, contentTopPadding)
            .offset(y: OnboardingLayoutMetrics.insightContentVerticalOffset)

            HStack(spacing: 16) {
                ForEach(pages, id: \.self) { page in
                    Circle()
                        .fill(
                            page == selection
                                ? Color.accentColor
                                : Color.accentColor.opacity(
                                    colorScheme == .dark ? 0.30 : 0.36
                                )
                        )
                        .frame(width: 10, height: 10)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .offset(y: OnboardingLayoutMetrics.insightContentVerticalOffset)

            Spacer(minLength: buttonSpacing)

            OnboardingPrimaryButton(action: onContinue) {
                Text("Continue")
            }
            .padding(.horizontal, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, bottomPadding)
    }

    private var selectionIndex: Int {
        pages.firstIndex(of: selection) ?? 0
    }

    private var resistedDragOffset: CGFloat {
        let isDraggingPastFirst = selection == pages.first && dragOffset > 0
        let isDraggingPastLast = selection == pages.last && dragOffset < 0
        return isDraggingPastFirst || isDraggingPastLast
            ? dragOffset * OnboardingInteractionMetrics.edgeDragResistance
            : dragOffset
    }

    private var pageDragGesture: some Gesture {
        DragGesture(
            minimumDistance: OnboardingInteractionMetrics.minimumDragDistance
        )
            .onChanged { value in
                guard abs(value.translation.width)
                    > abs(value.translation.height)
                else { return }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width)
                    > abs(value.translation.height)
                else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        dragOffset = 0
                    }
                    return
                }

                let projectedWidth = value.predictedEndTranslation.width
                let pageOffset: Int

                if projectedWidth
                    < -OnboardingInteractionMetrics.pageChangeThreshold {
                    pageOffset = 1
                } else if projectedWidth
                    > OnboardingInteractionMetrics.pageChangeThreshold {
                    pageOffset = -1
                } else {
                    pageOffset = 0
                }

                completeDrag(pageOffset: pageOffset)
            }
    }

    private func completeDrag(pageOffset: Int) {
        let pageIndex = min(
            pages.count - 1,
            max(0, selectionIndex + pageOffset)
        )

        withAnimation(.easeInOut(
            duration: OnboardingInteractionMetrics.pageAnimationDuration
        )) {
            selection = pages[pageIndex]
            dragOffset = 0
        }
    }
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
                Text("1h 30m remaining")
                    .font(.system(
                        size: OnboardingTypography.systemUI,
                        weight: .semibold
                    ))

                Text("You’ve used half of your daily limit.")
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
        .background(notificationBackground, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
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

    var steps: [String] {
        switch self {
        case .lockScreen:
            [
                "Touch and hold your Lock Screen, then tap Customize.",
                "Choose Lock Screen and tap the widget area below/above the clock.",
                "Find Mujø in the widget list and tap the widget to add it."
            ]
        case .homeScreen:
            [
                "Touch and hold an empty area of your Home Screen.",
                "Tap Edit, then tap Add Widget.",
                "Find Mujø, choose a widget, and tap Add Widget."
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

                            Text(step)
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

struct OnboardingLimitSetupView: View {

    fileprivate enum Step {
        case insights
        case chooseLimit
        case savings
        case notifications
        case lockScreenWidget
        case homeScreenWidget
    }

    @ObservedObject var screenTime: ScreenTimeManager
    @Binding var windStrength: Double
    @Environment(\.colorScheme) private var colorScheme
    let onCompleted: () -> Void
    private let usesPreviewData: Bool

    @State private var step: Step = .insights
    @State private var insightPage: OnboardingInsightPage = .day
    @State private var selectedMinutes = 0
    @State private var isSaving = false
    @State private var shouldLoadLimitReport = false
    @State private var isRequestingNotifications = false
    @State private var widgetHelp: OnboardingWidgetHelp?
    @StateObject private var notificationAuthorization = NotificationAuthorization()
    @State private var savingsPage: OnboardingSavingsPage = .day
    @AppStorage("wasNotificationPromptShown")
    private var wasNotificationPromptShown = false

    init(
        screenTime: ScreenTimeManager,
        windStrength: Binding<Double>,
        usesPreviewData: Bool = false,
        onCompleted: @escaping () -> Void
    ) {
        _screenTime = ObservedObject(wrappedValue: screenTime)
        _windStrength = windStrength
        _selectedMinutes = State(
            initialValue: usesPreviewData
                ? OnboardingPreviewData.initialLimitMinutes
                : 0
        )
        self.usesPreviewData = usesPreviewData
        self.onCompleted = onCompleted
    }

#if DEBUG
    fileprivate init(
        previewStep: Step,
        insightPage: OnboardingInsightPage = .day
    ) {
        _screenTime = ObservedObject(wrappedValue: ScreenTimeManager())
        _windStrength = .constant(0)
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

    private var yearlyReportFilter: DeviceActivityFilter {
        let calendar = Calendar.autoupdatingCurrent
        let end = calendar.startOfDay(for: .now)
        let start = calendar.date(
            byAdding: .day,
            value: -OnboardingProjectionRules.annualDayCount,
            to: end
        ) ?? end

        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: end)),
            users: .all,
            devices: .all
        )
    }

    var body: some View {
        ZStack {
            insightsStep
                .opacity(step == .insights ? 1 : 0)
                .allowsHitTesting(step == .insights)
                .accessibilityHidden(step != .insights)

            chooseLimitStep
                .opacity(step == .chooseLimit ? 1 : 0)
                .allowsHitTesting(step == .chooseLimit)
                .accessibilityHidden(step != .chooseLimit)

            savingsStep
                .opacity(step == .savings ? 1 : 0)
                .allowsHitTesting(step == .savings)
                .accessibilityHidden(step != .savings)

            notificationsStep
                .opacity(step == .notifications ? 1 : 0)
                .allowsHitTesting(step == .notifications)
                .accessibilityHidden(step != .notifications)

            lockScreenWidgetStep
                .opacity(step == .lockScreenWidget ? 1 : 0)
                .allowsHitTesting(step == .lockScreenWidget)
                .accessibilityHidden(step != .lockScreenWidget)

            homeScreenWidgetStep
                .opacity(step == .homeScreenWidget ? 1 : 0)
                .allowsHitTesting(step == .homeScreenWidget)
                .accessibilityHidden(step != .homeScreenWidget)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(
            .easeInOut(
                duration: OnboardingInteractionMetrics.stepAnimationDuration
            ),
            value: step
        )
        .task {
            await preloadLimitReport()
        }
        .sheet(item: $widgetHelp) { help in
            OnboardingWidgetHelpSheet(help: help)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var insightsStep: some View {
        OnboardingCardsPager(
            selection: $insightPage,
            pages: OnboardingInsightPage.allCases,
            contentTopPadding: 40,
            buttonSpacing: 24,
            bottomPadding: 34,
            onContinue: advanceInsight,
            headerContent: {
                Text("Before you\nchoose, know\nwhere you are")
                    .font(MujoTheme.boldFont(
                        size: 40,
                        relativeTo: .largeTitle
                    ))
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)
                    .padding(
                        .top,
                        OnboardingLayoutMetrics.topHeadingPadding
                    )
            }
        ) { page in
            report(
                context: page.context,
                filter: page == .year
                    ? yearlyReportFilter
                    : sevenDayReportFilter
            )
        }
    }

    private func advanceInsight() {
        guard let nextPage = OnboardingInsightPage(
            rawValue: insightPage.rawValue + 1
        ) else {
            step = .chooseLimit
            return
        }

        withAnimation(.easeInOut(
            duration: OnboardingInteractionMetrics.pageAnimationDuration
        )) {
            insightPage = nextPage
        }
    }

    private var chooseLimitStep: some View {
        VStack(spacing: 0) {
            ZStack {
                if shouldLoadLimitReport {
                    report(
                        context: .mujoLimitPrompt,
                        filter: sevenDayReportFilter
                    )
                }
            }
            .allowsHitTesting(false)
            .frame(
                minHeight: OnboardingLayoutMetrics.limitReportMinimumHeight,
                maxHeight: OnboardingLayoutMetrics.limitReportMaximumHeight
            )
            .layoutPriority(1)
            .padding(.horizontal, 26)
            .padding(
                .top,
                OnboardingLayoutMetrics.topHeadingPadding
            )

            Spacer(minLength: 12)

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
                windStrength: $windStrength,
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
                Group {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text(buttonTitle)
                    }
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
        .padding(.bottom, 10)
    }

    private var savingsStep: some View {
        AdaptiveOnboardingStep {
            VStack(spacing: 0) {
                OnboardingCardsPager(
                    selection: $savingsPage,
                    pages: OnboardingSavingsPage.allCases,
                    contentTopPadding: 12,
                    buttonSpacing: 8,
                    bottomPadding: 0,
                    onContinue: advanceSavings,
                    headerContent: { savingsHeader }
                ) { page in
                    report(
                        context: page.context,
                        filter: yearlyReportFilter
                    )
                }

                OnboardingSecondaryButton(
                    title: "Change limit",
                    action: changeLimit
                )
                .padding(.top, 5)
            }
            .padding(.bottom, 8)
        }
    }

    private var savingsHeader: some View {
        VStack(spacing: 0) {
            Text("Your new limit\nis set")
                .font(MujoTheme.boldFont(
                    size: 40,
                    relativeTo: .largeTitle
                ))
                .foregroundStyle(.tint)
                .multilineTextAlignment(.center)
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
                .padding(.top, 8)
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
                        Text("Enable notifications")
                    }
                }
                .padding(.horizontal, 34)

                OnboardingSecondaryButton(title: "Not now") {
                    finishNotificationStep()
                }
                .padding(.top, 5)
            }
            .padding(.bottom, 8)
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
            subtitle: "See what’s remaining\nwithout opening Mujø",
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
            await notificationAuthorization.requestAuthorization()
            isRequestingNotifications = false
            finishNotificationStep()
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

    private func preloadLimitReport() async {
        if usesPreviewData {
            shouldLoadLimitReport = true
            return
        }

        try? await Task.sleep(
            for: OnboardingInteractionMetrics.reportPreloadDelay
        )
        guard !Task.isCancelled else { return }
        shouldLoadLimitReport = true
    }

    @ViewBuilder
    private func report(
        context: DeviceActivityReport.Context,
        filter: DeviceActivityFilter
    ) -> some View {
        if usesPreviewData {
            previewReport(context: context)
        } else if context == .mujoDailyAverage {
            OnboardingInitialReport(
                context: context,
                filter: filter
            )
        } else {
            DeviceActivityReport(context, filter: filter)
                .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder
    private func previewReport(
        context: DeviceActivityReport.Context
    ) -> some View {
        if context == .mujoDailyAverage {
            OnboardingInsightCard(
                value: "3h\n30m",
                primaryCaption: .init("your ", emphasis: "daily average"),
                secondaryCaption: .init(
                    "over the ",
                    emphasis: "last 7 days"
                )
            )
        } else if context == .mujoWeeklyTotal {
            OnboardingInsightCard(
                value: "24h\n30m",
                primaryCaption: .init("your ", emphasis: "actual screen time"),
                secondaryCaption: .init(
                    "over the ",
                    emphasis: "last 7 days"
                )
            )
        } else if context == .mujoYearlyTotal {
            OnboardingInsightCard(
                value: "53d\n5h",
                primaryCaption: .init("at this pace,"),
                secondaryCaption: .init("in one ", emphasis: "year")
            )
        } else if context == .mujoLimitPrompt {
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

            VStack(spacing: 12) {
                Text("Start with a\nsmall change")
                    .font(.system(
                        size: 40,
                        weight: .bold,
                        design: .rounded
                    ))

                Text("Your average \(average) a day.\nTry starting with \(suggestion).")
                .font(MujoTheme.italicFont(
                    size: OnboardingTypography.descriptive,
                    relativeTo: .body
                ))
            }
            .foregroundStyle(.tint)
            .multilineTextAlignment(.center)
        } else if context == .mujoDailySavings {
            previewSavingsReport(page: 0)
        } else if context == .mujoWeeklySavings {
            previewSavingsReport(page: 1)
        } else if context == .mujoAnnualSavings {
            previewSavingsReport(page: 2)
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

    private var buttonTitle: String {
        "Set limit"
    }

    private func changeLimit() {
        withAnimation(.easeInOut(
            duration: OnboardingInteractionMetrics.stepAnimationDuration
        )) {
            step = .chooseLimit
        }
    }

    private func advanceSavings() {
        guard let nextPage = OnboardingSavingsPage(
            rawValue: savingsPage.rawValue + 1
        ) else {
            step = .notifications
            return
        }

        withAnimation(.easeInOut(
            duration: OnboardingInteractionMetrics.pageAnimationDuration
        )) {
            savingsPage = nextPage
        }
    }

    private func saveLimit() {
        guard selectedMinutes > 0, !isSaving else { return }

        if usesPreviewData {
            savingsPage = .day
            withAnimation(.easeInOut(
                duration: OnboardingInteractionMetrics.stepAnimationDuration
            )) {
                step = .savings
            }
            return
        }

        isSaving = true

        Task {
            await screenTime.setDailyLimit(minutes: selectedMinutes)
            isSaving = false

            guard screenTime.isAuthorized,
                  screenTime.errorMessage == nil
            else { return }

            savingsPage = .day
            withAnimation(.easeInOut(
                duration: OnboardingInteractionMetrics.stepAnimationDuration
            )) {
                step = .savings
            }
        }
    }
}

#if DEBUG
private struct OnboardingScreenPreview: View {
    let step: OnboardingLimitSetupView.Step
    var insightPage: OnboardingInsightPage = .day

    var body: some View {
        ZStack {
            SakuraBackground()
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

#Preview("06 · Notifications") {
    OnboardingScreenPreview(step: .notifications)
}

#Preview("07 · Lock Screen widget") {
    OnboardingScreenPreview(step: .lockScreenWidget)
}

#Preview("08 · Home Screen widget") {
    OnboardingScreenPreview(step: .homeScreenWidget)
}
#endif
