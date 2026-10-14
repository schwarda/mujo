import DeviceActivity
import Foundation
import SwiftUI

struct OnboardingSuggestionConfiguration: Equatable, Sendable {
    let totalMinutes: Int?
    let recentTotalMinutes: Int?
    let averageMinutes: Int?
    let suggestedMinutes: Int?
    let dailyLimitMinutes: Int?
    let availableDayCount: Int
    let recentAvailableDayCount: Int

    nonisolated static let unavailable = Self(
        totalMinutes: nil,
        recentTotalMinutes: nil,
        averageMinutes: nil,
        suggestedMinutes: nil,
        dailyLimitMinutes: nil,
        availableDayCount: 0,
        recentAvailableDayCount: 0
    )
}

enum OnboardingAverageScope: Sendable {
    case allAvailableDays
    case recentDays
}

enum OnboardingSuggestionCalculator {
    nonisolated static func configuration(
        dailyTotals: [Date: TimeInterval],
        averageScope: OnboardingAverageScope,
        dailyLimitMinutes: Int?
    ) -> OnboardingSuggestionConfiguration {
        let totalSeconds = dailyTotals.values.reduce(0, +)
        guard !dailyTotals.isEmpty, totalSeconds > 0 else {
            return .unavailable
        }

        let recentSource = dailyTotals
            .sorted { $0.key < $1.key }
            .suffix(OnboardingProjectionRules.recentDayCount)
            .map(\.value)
        let averageSource: [TimeInterval]
        switch averageScope {
        case .allAvailableDays:
            averageSource = Array(dailyTotals.values)
        case .recentDays:
            averageSource = recentSource
        }

        let averageSeconds = averageSource.reduce(0, +)
        let averageMinutes = max(
            1,
            Int((averageSeconds / Double(averageSource.count) / 60).rounded())
        )
        let stepMinutes = OnboardingProjectionRules.limitStepMinutes
        let suggestedMinutes = max(
            OnboardingProjectionRules.minimumLimitMinutes,
            Int(
                (
                    Double(averageMinutes)
                        * OnboardingProjectionRules.suggestedLimitRatio
                        / Double(stepMinutes)
                ).rounded()
            ) * stepMinutes
        )

        return OnboardingSuggestionConfiguration(
            totalMinutes: max(1, Int((totalSeconds / 60).rounded())),
            recentTotalMinutes: max(
                1,
                Int((recentSource.reduce(0, +) / 60).rounded())
            ),
            averageMinutes: averageMinutes,
            suggestedMinutes: suggestedMinutes,
            dailyLimitMinutes: dailyLimitMinutes,
            availableDayCount: dailyTotals.count,
            recentAvailableDayCount: recentSource.count
        )
    }
}

extension DeviceActivityReport.Context {
    nonisolated static let mujoInsightsCarousel = Self(
        "Mujo Insights Carousel"
    )
    nonisolated static let mujoDailyAverage = Self("Mujo Daily Average")
    nonisolated static let mujoWeeklyTotal = Self("Mujo Weekly Total")
    nonisolated static let mujoYearlyTotal = Self("Mujo Yearly Total")
    nonisolated static let mujoLimitEditorDescription = Self(
        "Mujo Limit Editor Description"
    )
    nonisolated static let mujoDailySavings = Self("Mujo Daily Savings")
    nonisolated static let mujoWeeklySavings = Self("Mujo Weekly Savings")
    nonisolated static let mujoAnnualSavings = Self("Mujo Annual Savings")
    nonisolated static let mujoSavingsCarousel = Self(
        "Mujo Savings Carousel"
    )
}

// Screen Time data stays inside the system report extension. Keep its view
// unchanged when unrelated host state (for example the limit dial) changes.
struct ScreenTimeReportView: View, Equatable {
    let context: DeviceActivityReport.Context
    let filter: DeviceActivityFilter

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.context == rhs.context && lhs.filter == rhs.filter
    }

    var body: some View {
        DeviceActivityReport(context, filter: filter)
    }
}

enum OnboardingProjectionRules {
    nonisolated static let recentDayCount = 7
    nonisolated static let annualDayCount = 365
    nonisolated static let suggestedLimitRatio = 0.85

    nonisolated static var limitStepMinutes: Int {
        AppConfiguration.DailyLimit.stepMinutes
    }

    nonisolated static var minimumLimitMinutes: Int {
        AppConfiguration.DailyLimit.minimumMinutes
    }
}

enum OnboardingDurationFormatter {
    nonisolated static func string(
        minutes totalMinutes: Int,
        emptyPlaceholder: String? = nil
    ) -> String {
        guard totalMinutes > 0 else {
            return emptyPlaceholder ?? "0m"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        guard hours > 0 else {
            return "\(minutes)m"
        }

        return String(format: "%dh %02dm", hours, minutes)
    }
}

enum OnboardingCardDurationFormatter {
    nonisolated static func string(minutes totalMinutes: Int) -> String {
        let safeMinutes = max(0, totalMinutes)
        let hours = safeMinutes / 60
        let minutes = safeMinutes % 60
        return String(format: "%dh\n%02dm", hours, minutes)
    }
}

enum OnboardingYearDurationFormatter {
    nonisolated static func string(minutes totalMinutes: Int) -> String {
        let totalHours = max(0, totalMinutes) / 60
        let days = totalHours / 24
        let hours = totalHours % 24
        return String(format: "%dd\n%dh", days, hours)
    }
}

enum OnboardingSavingsDurationFormatter {
    nonisolated static func string(minutes totalMinutes: Int) -> String {
        let safeMinutes = max(0, totalMinutes)
        let totalHours = safeMinutes / 60

        if totalHours >= 24 {
            let days = totalHours / 24
            let hours = totalHours % 24
            return String(format: "%dd\n%dh", days, hours)
        }

        let minutes = safeMinutes % 60
        return String(format: "%dh\n%02dm", totalHours, minutes)
    }
}

nonisolated enum OnboardingScreenTimeDifferenceDirection: Equatable {
    case less
    case more
}

nonisolated struct OnboardingScreenTimeDifference: Equatable {
    let minutes: Int
    let direction: OnboardingScreenTimeDifferenceDirection
}

enum OnboardingAnnualSavingsCalculator {
    nonisolated static func difference(
        annualTotalMinutes: Int,
        recentDailyAverageMinutes: Int,
        availableDayCount: Int,
        dailyLimitMinutes: Int
    ) -> OnboardingScreenTimeDifference {
        let annualBaseline = availableDayCount
            >= OnboardingProjectionRules.annualDayCount
            ? annualTotalMinutes
            : recentDailyAverageMinutes
                * OnboardingProjectionRules.annualDayCount
        let limitedAnnualTotal = max(0, dailyLimitMinutes)
            * OnboardingProjectionRules.annualDayCount
        let signedDifference = annualBaseline - limitedAnnualTotal

        return OnboardingScreenTimeDifference(
            minutes: abs(signedDifference),
            direction: signedDifference >= 0 ? .less : .more
        )
    }
}

struct OnboardingInsightCard: View {
    let value: String
    let primaryCaption: OnboardingInsightCaption
    let secondaryCaption: OnboardingInsightCaption
    var horizontalPadding: CGFloat = 28


    var body: some View {
        ZStack {
            VStack(spacing: -12) {
                ForEach(timeLines.indices, id: \.self) { index in
                    Text(timeLines[index])
                        .font(.system(
                            size: 88,
                            weight: .bold,
                            design: .rounded
                        ))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(primaryColor)
            .offset(y: -22)

            VStack {
                Spacer()

                VStack(spacing: 1) {
                    primaryCaption.text
                    secondaryCaption.text
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(primaryColor)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 18)
        .glassEffect(.clear, in: .rect(cornerRadius: 36))
        .shadow(
            color: MujoTheme.brandAccent.opacity(0.20),
            radius: 16,
            y: 10
        )
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, 32)
    }

    private var primaryColor: Color {
        MujoTheme.brandAccent
    }

    private var timeLines: [String] {
        value.split(separator: "\n").map(String.init)
    }

}

struct OnboardingInsightCaption {
    let leading: String
    let emphasis: String
    let trailing: String

    init(
        _ leading: String = "",
        emphasis: String = "",
        trailing: String = ""
    ) {
        self.leading = leading
        self.emphasis = emphasis
        self.trailing = trailing
    }

    var text: Text {
        let emphasizedText = Text(verbatim: emphasis)
            .font(MujoTheme.semiboldItalicFont(
                size: OnboardingTypography.descriptive,
                relativeTo: .body
            ))

        return Text("\(leading)\(emphasizedText)\(trailing)")
            .font(MujoTheme.italicFont(
                size: OnboardingTypography.descriptive,
                relativeTo: .body
            ))
    }
}

struct OnboardingSavingsCard: View {
    let annualDifference: OnboardingScreenTimeDifference
    let page: Int
    var horizontalPadding: CGFloat = 28

    var body: some View {
        switch page {
        case 0:
            savingsCard(
                value: OnboardingCardDurationFormatter.string(
                    minutes: dailyDifferenceMinutes
                ),
                period: "every day"
            )
        case 1:
            savingsCard(
                value: OnboardingCardDurationFormatter.string(
                    minutes: weeklyDifferenceMinutes
                ),
                period: "every week"
            )
        default:
            savingsCard(
                value: OnboardingSavingsDurationFormatter.string(
                    minutes: annualDifference.minutes
                ),
                period: "over the next year"
            )
        }
    }

    private var dailyDifferenceMinutes: Int {
        Int((Double(annualDifference.minutes) / 365).rounded())
    }

    private var weeklyDifferenceMinutes: Int {
        dailyDifferenceMinutes * 7
    }

    private func savingsCard(value: String, period: String) -> some View {
        OnboardingInsightCard(
            value: value,
            primaryCaption: .init(emphasis: differenceCaption),
            secondaryCaption: .init(emphasis: period),
            horizontalPadding: horizontalPadding
        )
    }

    private var differenceCaption: String {
        switch annualDifference.direction {
        case .less:
            "less screen time"
        case .more:
            "more screen time"
        }
    }
}
