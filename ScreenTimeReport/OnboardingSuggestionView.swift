import Foundation
import SwiftUI

private struct OnboardingReportBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MujoTheme.onboardingBackground(for: colorScheme)
            .ignoresSafeArea()
    }
}

enum OnboardingReportPresentation: Equatable {
    case insightsCarousel
    case savingsCarousel
    case dailyAverage
    case weeklyTotal
    case yearlyTotal
    case limitPrompt
    case limitEditorDescription
    case dailySavings
    case weeklySavings
    case annualSavings

}

private struct OnboardingSavingsCarouselView: View {
    let configuration: OnboardingSuggestionConfiguration

    @Environment(\.colorScheme) private var colorScheme
    @SceneStorage("mujo.onboarding.savingsCarousel.selectedPage")
    private var selectedPage = 0
    @State private var liveSelection: Int?

    private let pages = Array(0..<3)

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let cardWidth = max(0, geometry.size.width - 72)
                let sideInset = (geometry.size.width - cardWidth) / 2

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(pages, id: \.self) { page in
                            card(for: page)
                                .frame(width: cardWidth)
                                .id(page)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(
                    .horizontal,
                    sideInset,
                    for: .scrollContent
                )
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $liveSelection)
                .onAppear {
                    liveSelection = selectedPage
                }
                .onChange(of: liveSelection) { _, newValue in
                    guard let newValue, pages.contains(newValue) else { return }
                    selectedPage = newValue
                }
            }
            .frame(maxHeight: .infinity)
            .layoutPriority(1)

            HStack(spacing: 16) {
                ForEach(pages, id: \.self) { page in
                    Circle()
                        .fill(
                            page == (liveSelection ?? selectedPage)
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

    @ViewBuilder
    private func card(for page: Int) -> some View {
        if let totalMinutes = configuration.totalMinutes,
           let averageMinutes = configuration.averageMinutes {
            let dailyLimitMinutes = configuration.dailyLimitMinutes
                ?? averageMinutes
            let annualSavingsMinutes = OnboardingAnnualSavingsCalculator
                .minutes(
                    annualTotalMinutes: totalMinutes,
                    recentDailyAverageMinutes: averageMinutes,
                    availableDayCount: configuration.availableDayCount,
                    dailyLimitMinutes: dailyLimitMinutes
                )
            OnboardingSavingsCard(
                annualSavingsMinutes: annualSavingsMinutes,
                page: page,
                horizontalPadding: 0
            )
        } else {
            OnboardingInsightCard(
                value: "–",
                primaryCaption: .init(emphasis: "Screen Time data"),
                secondaryCaption: .init("isn't available yet"),
                horizontalPadding: 0
            )
        }
    }
}

private struct OnboardingInsightsCarouselView: View {
    let configuration: OnboardingSuggestionConfiguration

    @Environment(\.colorScheme) private var colorScheme
    @SceneStorage("mujo.onboarding.insightsCarousel.selectedPage")
    private var selectedPage = 0
    @State private var liveSelection: Int?

    private let pages = Array(0..<3)

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let cardWidth = max(0, geometry.size.width - 72)
                let sideInset = (geometry.size.width - cardWidth) / 2

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(pages, id: \.self) { page in
                            card(for: page)
                                .frame(width: cardWidth)
                                .id(page)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(
                    .horizontal,
                    sideInset,
                    for: .scrollContent
                )
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $liveSelection)
                .onAppear {
                    liveSelection = selectedPage
                }
                .onChange(of: liveSelection) { _, newValue in
                    guard let newValue, pages.contains(newValue) else { return }
                    selectedPage = newValue
                }
            }
            .frame(maxHeight: .infinity)
            .layoutPriority(1)

            HStack(spacing: 16) {
                ForEach(pages, id: \.self) { page in
                    Circle()
                        .fill(
                            page == (liveSelection ?? selectedPage)
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
    }

    @ViewBuilder
    private func card(for page: Int) -> some View {
        if let totalMinutes = configuration.totalMinutes,
           let averageMinutes = configuration.averageMinutes {
            switch page {
            case 0:
                OnboardingInsightCard(
                    value: OnboardingCardDurationFormatter.string(
                        minutes: averageMinutes
                    ),
                    primaryCaption: .init(
                        "your ",
                        emphasis: "daily average"
                    ),
                    secondaryCaption: hasFullWeek
                        ? .init("over the ", emphasis: "last 7 days")
                        : .init(
                            "based on ",
                            emphasis: "\(configuration.recentAvailableDayCount) available days"
                        ),
                    horizontalPadding: 0
                )

            case 1:
                let weeklyMinutes = hasFullWeek
                    ? configuration.recentTotalMinutes ?? totalMinutes
                    : averageMinutes * OnboardingProjectionRules.recentDayCount
                OnboardingInsightCard(
                    value: OnboardingCardDurationFormatter.string(
                        minutes: weeklyMinutes
                    ),
                    primaryCaption: hasFullWeek
                        ? .init("your ", emphasis: "actual screen time")
                        : .init("at this pace,"),
                    secondaryCaption: hasFullWeek
                        ? .init("over the ", emphasis: "last 7 days")
                        : .init("each ", emphasis: "week"),
                    horizontalPadding: 0
                )

            default:
                let hasFullYear = configuration.availableDayCount
                    >= OnboardingProjectionRules.annualDayCount
                let yearlyMinutes = hasFullYear
                    ? totalMinutes
                    : averageMinutes * OnboardingProjectionRules.annualDayCount
                OnboardingInsightCard(
                    value: OnboardingYearDurationFormatter.string(
                        minutes: yearlyMinutes
                    ),
                    primaryCaption: hasFullYear
                        ? .init("your ", emphasis: "actual screen time")
                        : .init("at this pace,"),
                    secondaryCaption: hasFullYear
                        ? .init("over the ", emphasis: "last year")
                        : .init("in one ", emphasis: "year"),
                    horizontalPadding: 0
                )
            }
        } else {
            OnboardingInsightCard(
                value: "–",
                primaryCaption: .init(emphasis: "Screen Time data"),
                secondaryCaption: .init("isn't available yet"),
                horizontalPadding: 0
            )
        }
    }

    private var hasFullWeek: Bool {
        configuration.recentAvailableDayCount
            >= OnboardingProjectionRules.recentDayCount
    }

}

struct OnboardingReportContentView: View {
    let configuration: OnboardingSuggestionConfiguration
    let presentation: OnboardingReportPresentation

    var body: some View {
#if DEBUG
        let _ = PerformanceDiagnostics.startFrameMonitoring()
        let _ = PerformanceDiagnostics.throttledLog(
            key: "OnboardingReportContentView.body.\(String(describing: presentation))",
            minimumInterval: 0.10,
            "swiftui-body",
            "report content body; presentation=\(String(describing: presentation))"
        )
#endif
        GeometryReader { geometry in
            let effectivePresentation = effectivePresentation(
                forHeight: geometry.size.height
            )
            OnboardingSuggestionView(
                configuration: configuration,
                presentation: effectivePresentation
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
#if DEBUG
                PerformanceDiagnostics.markPhase(
                    "report-extension.content.appeared.\(String(describing: effectivePresentation))"
                )
                PerformanceDiagnostics.log(
                    "report-extension",
                    "content appeared; requested=\(String(describing: presentation)), effective=\(String(describing: effectivePresentation)), size=\(String(describing: geometry.size))"
                )
#endif
            }
            .onDisappear {
#if DEBUG
                PerformanceDiagnostics.log(
                    "report-extension",
                    "content disappeared; requested=\(String(describing: presentation)), effective=\(String(describing: effectivePresentation))"
                )
#endif
            }
            .onChange(of: geometry.size) { oldSize, newSize in
#if DEBUG
                PerformanceDiagnostics.log(
                    "report-extension",
                    "geometry changed \(String(describing: oldSize)) -> \(String(describing: newSize)); effective=\(String(describing: self.effectivePresentation(forHeight: newSize.height)))"
                )
#endif
            }
            .onChange(of: effectivePresentation) { oldValue, newValue in
#if DEBUG
                PerformanceDiagnostics.log(
                    "report-extension",
                    "presentation changed \(String(describing: oldValue)) -> \(String(describing: newValue))"
                )
#endif
            }
        }
    }

    private func effectivePresentation(
        forHeight height: CGFloat
    ) -> OnboardingReportPresentation {
        if presentation == .insightsCarousel, height < 160 {
            return .limitPrompt
        }
        return presentation
    }
}

struct OnboardingSuggestionView: View {
    let configuration: OnboardingSuggestionConfiguration
    let presentation: OnboardingReportPresentation


    var body: some View {
#if DEBUG
        let _ = PerformanceDiagnostics.throttledLog(
            key: "OnboardingSuggestionView.body.\(String(describing: presentation))",
            minimumInterval: 0.10,
            "swiftui-body",
            "suggestion view body; presentation=\(String(describing: presentation)), days=\(configuration.availableDayCount)"
        )
#endif
        Group {
            if let totalMinutes = configuration.totalMinutes,
               let averageMinutes = configuration.averageMinutes,
               let suggestedMinutes = configuration.suggestedMinutes {
                availableReport(
                    totalMinutes: totalMinutes,
                    averageMinutes: averageMinutes,
                    suggestedMinutes: suggestedMinutes
                )
            } else {
                unavailableReport
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if presentation == .insightsCarousel
                || presentation == .savingsCarousel
                || presentation == .dailyAverage
                || presentation == .limitPrompt
                || presentation == .limitEditorDescription {
                OnboardingReportBackground()
            } else {
                Color.clear
            }
        }
        .accessibilityElement(
            children: presentation == .insightsCarousel
                || presentation == .savingsCarousel
                ? .contain
                : .combine
        )
    }

    @ViewBuilder
    private func availableReport(
        totalMinutes: Int,
        averageMinutes: Int,
        suggestedMinutes: Int
    ) -> some View {
        switch presentation {
        case .insightsCarousel:
            OnboardingInsightsCarouselView(configuration: configuration)

        case .savingsCarousel:
            OnboardingSavingsCarouselView(configuration: configuration)

        case .dailyAverage:
            OnboardingInsightCard(
                value: cardFormatted(averageMinutes),
                primaryCaption: .init(
                    "your ",
                    emphasis: "daily average"
                ),
                secondaryCaption: configuration.availableDayCount
                    >= OnboardingProjectionRules.recentDayCount
                    ? .init("over the ", emphasis: "last 7 days")
                    : .init(
                        "based on ",
                        emphasis: "\(configuration.availableDayCount) available days"
                    )
            )

        case .weeklyTotal:
            let hasFullWeek = configuration.availableDayCount
                >= OnboardingProjectionRules.recentDayCount
            let weeklyMinutes = hasFullWeek
                ? totalMinutes
                : averageMinutes * OnboardingProjectionRules.recentDayCount
            OnboardingInsightCard(
                value: cardFormatted(weeklyMinutes),
                primaryCaption: hasFullWeek
                    ? .init("your ", emphasis: "actual screen time")
                    : .init("at this pace,"),
                secondaryCaption: hasFullWeek
                    ? .init("over the ", emphasis: "last 7 days")
                    : .init("each ", emphasis: "week")
            )

        case .yearlyTotal:
            let hasFullYear = configuration.availableDayCount
                >= OnboardingProjectionRules.annualDayCount
            let yearlyMinutes = hasFullYear
                ? totalMinutes
                : averageMinutes * OnboardingProjectionRules.annualDayCount
            OnboardingInsightCard(
                value: OnboardingYearDurationFormatter.string(
                    minutes: yearlyMinutes
                ),
                primaryCaption: hasFullYear
                    ? .init("your ", emphasis: "actual screen time")
                    : .init("at this pace,"),
                secondaryCaption: hasFullYear
                    ? .init("over the ", emphasis: "last year")
                    : .init("in one ", emphasis: "year")
            )

        case .limitPrompt:
            VStack(spacing: 4) {
                averageText(averageMinutes)
                suggestionText(suggestedMinutes)
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(primaryColor)
            .padding(.horizontal, 12)

        case .limitEditorDescription:
            limitEditorDescription(averageMinutes: averageMinutes)

        case .dailySavings, .weeklySavings, .annualSavings:
            let dailyLimitMinutes = configuration.dailyLimitMinutes
                ?? averageMinutes
            let annualSavingsMinutes = OnboardingAnnualSavingsCalculator
                .minutes(
                    annualTotalMinutes: totalMinutes,
                    recentDailyAverageMinutes: averageMinutes,
                    availableDayCount: configuration.availableDayCount,
                    dailyLimitMinutes: dailyLimitMinutes
                )
            OnboardingSavingsCard(
                annualSavingsMinutes: annualSavingsMinutes,
                page: savingsPage
            )
        }
    }

    private var savingsPage: Int {
        switch presentation {
        case .dailySavings: 0
        case .weeklySavings: 1
        default: 2
        }
    }

    @ViewBuilder
    private var unavailableReport: some View {
        Group {
            if presentation == .insightsCarousel {
                OnboardingInsightsCarouselView(configuration: .unavailable)
            } else if presentation == .savingsCarousel {
                OnboardingSavingsCarouselView(configuration: .unavailable)
            } else if presentation == .limitPrompt {
                Text("Set the amount of screen time you want to give yourself each day.")
                    .font(MujoTheme.italicFont(
                        size: OnboardingTypography.descriptive,
                        relativeTo: .body
                    ))
                    .foregroundStyle(primaryColor)
                    .multilineTextAlignment(.center)
            } else if presentation == .limitEditorDescription {
                EmptyView()
            } else {
                OnboardingInsightCard(
                    value: "–",
                    primaryCaption: .init(emphasis: "Screen Time data"),
                    secondaryCaption: .init("isn't available yet")
                )
            }
        }
    }

    private var primaryColor: Color {
        MujoTheme.brandAccent
    }

    @ViewBuilder
    private func limitEditorDescription(averageMinutes: Int) -> some View {
        let averageLabel = emphasizedItalicText("average")
        let average = emphasizedItalicText(formatted(averageMinutes))

        Group {
            if configuration.availableDayCount
                >= OnboardingProjectionRules.recentDayCount {
                let lastSevenDays = emphasizedItalicText("last 7 days")
                Text(
                    "Your \(averageLabel): \(average)\nover the \(lastSevenDays)"
                )
            } else {
                let availableDays = emphasizedItalicText(
                    "\(configuration.availableDayCount) available days"
                )
                Text(
                    "Your \(averageLabel): \(average)\nbased on \(availableDays)"
                )
            }
        }
        .font(MujoTheme.italicFont(
            size: OnboardingTypography.descriptive,
            relativeTo: .body
        ))
        .multilineTextAlignment(.center)
        .foregroundStyle(primaryColor)
        .padding(.horizontal, 12)
    }

    private func averageText(_ averageMinutes: Int) -> Text {
        let average = emphasizedItalicText(formatted(averageMinutes))
        return italicText("Your average \(average) a day.")
    }

    private func suggestionText(_ suggestedMinutes: Int) -> Text {
        let suggestion = emphasizedItalicText(formatted(suggestedMinutes))
        return italicText("Try starting with \(suggestion).")
    }

    private func italicText(
        _ value: LocalizedStringKey,
        size: CGFloat = OnboardingTypography.descriptive
    ) -> Text {
        Text(value)
            .font(MujoTheme.italicFont(
                size: size,
                relativeTo: .body
            ))
    }

    private func emphasizedItalicText(
        _ value: String,
        size: CGFloat = OnboardingTypography.descriptive
    ) -> Text {
        Text(value)
            .font(MujoTheme.semiboldItalicFont(
                size: size,
                relativeTo: .body
            ))
    }

    private func formatted(_ totalMinutes: Int) -> String {
        OnboardingDurationFormatter.string(minutes: totalMinutes)
    }

    private func cardFormatted(_ totalMinutes: Int) -> String {
        OnboardingCardDurationFormatter.string(minutes: totalMinutes)
    }

}
