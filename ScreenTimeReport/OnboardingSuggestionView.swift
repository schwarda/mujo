import Foundation
import SwiftUI

struct OnboardingReportContentView: View {
    let configuration: OnboardingSuggestionConfiguration
    let presentation: OnboardingReportPresentation

    var body: some View {
        GeometryReader { geometry in
            let effectivePresentation = effectivePresentation(
                forHeight: geometry.size.height
            )
            OnboardingSuggestionView(
                configuration: configuration,
                presentation: effectivePresentation
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            let annualDifference = OnboardingAnnualSavingsCalculator
                .difference(
                    annualTotalMinutes: totalMinutes,
                    recentDailyAverageMinutes: averageMinutes,
                    availableDayCount: configuration.availableDayCount,
                    dailyLimitMinutes: dailyLimitMinutes
                )
            OnboardingSavingsCard(
                annualDifference: annualDifference,
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
        let aDay = Text("a day")
            .font(MujoTheme.semiboldItalicFont(
                size: OnboardingTypography.descriptive,
                relativeTo: .body
            ))
        return italicText("Your average is \(average) \(aDay).")
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
