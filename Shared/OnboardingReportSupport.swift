import DeviceActivity
import Foundation
import SwiftUI

extension DeviceActivityReport.Context {
    nonisolated static let mujoDailyAverage = Self("Mujo Daily Average")
    nonisolated static let mujoWeeklyTotal = Self("Mujo Weekly Total")
    nonisolated static let mujoYearlyTotal = Self("Mujo Yearly Total")
    nonisolated static let mujoLimitPrompt = Self("Mujo Limit Prompt")
    nonisolated static let mujoLimitEditorDescription = Self(
        "Mujo Limit Editor Description"
    )
    nonisolated static let mujoTodayUsage = Self("Mujo Today Usage")
    nonisolated static let mujoDailySavings = Self("Mujo Daily Savings")
    nonisolated static let mujoWeeklySavings = Self("Mujo Weekly Savings")
    nonisolated static let mujoAnnualSavings = Self("Mujo Annual Savings")
}

enum OnboardingReportStorage {
    nonisolated static let appGroupIdentifier =
        "group.AikariStudio.Mujo.shared"
    nonisolated static let dailyLimitSecondsKey = "dailyLimitSeconds"
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

enum OnboardingAnnualSavingsCalculator {
    nonisolated static func minutes(
        annualTotalMinutes: Int,
        recentDailyAverageMinutes: Int,
        availableDayCount: Int,
        dailyLimitMinutes: Int
    ) -> Int {
        let annualBaseline = availableDayCount
            >= OnboardingProjectionRules.annualDayCount
            ? annualTotalMinutes
            : recentDailyAverageMinutes
                * OnboardingProjectionRules.annualDayCount
        let limitedAnnualTotal = max(0, dailyLimitMinutes)
            * OnboardingProjectionRules.annualDayCount
        return max(0, annualBaseline - limitedAnnualTotal)
    }
}

struct OnboardingInsightCard: View {
    let value: String
    let primaryCaption: OnboardingInsightCaption
    let secondaryCaption: OnboardingInsightCaption


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
                .padding(.bottom, 12)
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
        .padding(.horizontal, 28)
        .padding(.vertical, 32)
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
    let annualSavingsMinutes: Int
    let page: Int

    var body: some View {
        switch page {
        case 0:
            savingsCard(
                value: OnboardingCardDurationFormatter.string(
                    minutes: dailySavingsMinutes
                ),
                period: "every day"
            )
        case 1:
            savingsCard(
                value: OnboardingCardDurationFormatter.string(
                    minutes: weeklySavingsMinutes
                ),
                period: "every week"
            )
        default:
            savingsCard(
                value: OnboardingSavingsDurationFormatter.string(
                    minutes: annualSavingsMinutes
                ),
                period: "over the next year"
            )
        }
    }

    private var dailySavingsMinutes: Int {
        Int((Double(annualSavingsMinutes) / 365).rounded())
    }

    private var weeklySavingsMinutes: Int {
        dailySavingsMinutes * 7
    }

    private func savingsCard(value: String, period: String) -> some View {
        OnboardingInsightCard(
            value: value,
            primaryCaption: .init("you could ", emphasis: "reclaim"),
            secondaryCaption: .init(
                "screen-free time ",
                emphasis: period
            )
        )
    }
}
