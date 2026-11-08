import Foundation
import SwiftUI

struct OnboardingReportBackground: View {
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

struct OnboardingSavingsCarouselView: View {
    let configuration: OnboardingSuggestionConfiguration

    @Environment(\.colorScheme) private var colorScheme
    @SceneStorage("mujo.onboarding.savingsCarousel.selectedPage")
    private var selectedPage = 0
    @State private var liveSelection: Int?

    private var pages: [Int] {
        hasHistory ? [0, 1, 2] : [1, 3, 2]
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(comparisonHeading)
                .font(MujoTheme.italicFont(
                    size: OnboardingTypography.descriptive,
                    relativeTo: .body
                ))
                .foregroundStyle(MujoTheme.brandAccent)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 34)
                .padding(.bottom, 6)

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
                    let page = pages.contains(selectedPage) ? selectedPage : pages[0]
                    selectedPage = page
                    liveSelection = page
                }
                .onChange(of: pages) { _, newPages in
                    guard !newPages.contains(liveSelection ?? selectedPage) else { return }
                    selectedPage = newPages[0]
                    liveSelection = newPages[0]
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

    private var hasHistory: Bool {
        configuration.totalMinutes != nil && configuration.averageMinutes != nil
    }

    private var comparisonHeading: String {
        if !hasHistory {
            return "Just 15 minutes less a day could mean…"
        }
        if configuration.recentAvailableDayCount == 1 {
            return "Compared with your screen time\nover the last day:"
        }
        return "Compared with your daily average:"
    }

    @ViewBuilder
    private func card(for page: Int) -> some View {
        if let totalMinutes = configuration.totalMinutes,
           let averageMinutes = configuration.averageMinutes {
            let dailyLimitMinutes = configuration.dailyLimitMinutes
                ?? averageMinutes
            let annualDifference = OnboardingAnnualSavingsCalculator
                .difference(
                    annualTotalMinutes: totalMinutes,
                    recentDailyAverageMinutes: averageMinutes,
                    availableDayCount: configuration.availableDayCount,
                    dailyLimitMinutes: dailyLimitMinutes
                )
            OnboardingSavingsCard(
                annualDifference: annualDifference,
                page: page,
                horizontalPadding: 0
            )
        } else {
            OnboardingInsightCard(
                value: exampleSavingsValue(for: page),
                primaryCaption: .init("more time"),
                secondaryCaption: exampleSavingsPeriod(for: page),
                horizontalPadding: 0
            )
        }
    }
    private func exampleSavingsValue(for page: Int) -> String {
        switch page {
        case 1: "1h\n45m"
        case 3: "7h\n30m"
        default: "91h"
        }
    }

    private func exampleSavingsPeriod(for page: Int) -> OnboardingInsightCaption {
        switch page {
        case 1: .init("every ", emphasis: "week")
        case 3: .init("every ", emphasis: "month")
        default: .init("every ", emphasis: "year")
        }
    }
}

struct OnboardingInsightsCarouselView: View {
    let configuration: OnboardingSuggestionConfiguration

    @Environment(\.colorScheme) private var colorScheme
    @SceneStorage("mujo.onboarding.insightsCarousel.selectedPage")
    private var selectedPage = 0
    @State private var liveSelection: Int?

    private let pages = Array(0..<3)

    @ViewBuilder
    var body: some View {
        if configuration.totalMinutes != nil,
           configuration.averageMinutes != nil {
            insightsCarousel
        } else {
            Text("Yesterday doesn't\nhave to define today.")
                .font(MujoTheme.italicFont(size: 28, relativeTo: .title2))
                .foregroundStyle(MujoTheme.brandAccent)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var insightsCarousel: some View {
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
                    primaryCaption: configuration.recentAvailableDayCount == 1
                        ? .init("your ", emphasis: "screen time")
                        : .init("your ", emphasis: "daily average"),
                    secondaryCaption: recentPeriodCaption,
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
                        : .init("in one ", emphasis: "week"),
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

    private var recentPeriodCaption: OnboardingInsightCaption {
        if configuration.recentAvailableDayCount == 1 {
            return .init("over the ", emphasis: "last day")
        }
        if hasFullWeek {
            return .init("over the ", emphasis: "last 7 days")
        }
        return .init(
            "over the ",
            emphasis: "last \(configuration.recentAvailableDayCount) days"
        )
    }

}
