import Foundation
import SwiftUI

enum OnboardingReportPresentation: Equatable {
    case dailyAverage
    case weeklyTotal
    case yearlyTotal
    case limitPrompt
    case limitEditorDescription
    case dailySavings
    case weeklySavings
    case annualSavings

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
        .background(Color.clear)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func availableReport(
        totalMinutes: Int,
        averageMinutes: Int,
        suggestedMinutes: Int
    ) -> some View {
        switch presentation {
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
                    : .init("from available ", emphasis: "Screen Time data")
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
            VStack(spacing: 12) {
                Text(
                    suggestedMinutes == averageMinutes
                        ? "Take the first step"
                        : "Start with a\nsmall change"
                )
                .font(.system(
                    size: 40,
                    weight: .bold,
                    design: .rounded
                ))
                .multilineTextAlignment(.center)
                .foregroundStyle(primaryColor)

                VStack(spacing: 4) {
                    averageText(averageMinutes)
                    suggestionText(suggestedMinutes)
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(primaryColor)
            }
            .padding(.horizontal, 12)

        case .limitEditorDescription:
            let averageLabel = emphasizedItalicText("average")
            let average = emphasizedItalicText(formatted(averageMinutes))
            let lastSevenDays = emphasizedItalicText("last 7 days")
            italicText("Your \(averageLabel): \(average)\nover the \(lastSevenDays)")
            .multilineTextAlignment(.center)
            .foregroundStyle(primaryColor)
            .padding(.horizontal, 12)

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
            if presentation == .limitPrompt {
                Text("Take the first step")
                    .font(.system(
                        size: 40,
                        weight: .bold,
                        design: .rounded
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
