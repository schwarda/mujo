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

struct OnboardingInsightsCarouselView: View {
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
