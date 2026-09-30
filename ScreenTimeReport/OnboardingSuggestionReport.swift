import DeviceActivity
import ExtensionKit
import Foundation
import SwiftUI

struct OnboardingSuggestionConfiguration {
    let totalMinutes: Int?
    let averageMinutes: Int?
    let suggestedMinutes: Int?
    let dailyLimitMinutes: Int?
    let availableDayCount: Int

    static let unavailable = Self(
        totalMinutes: nil,
        averageMinutes: nil,
        suggestedMinutes: nil,
        dailyLimitMinutes: nil,
        availableDayCount: 0
    )
}

struct OnboardingSuggestionReport: nonisolated DeviceActivityReportScene {
    let context: DeviceActivityReport.Context
    let content: (
        OnboardingSuggestionConfiguration
    ) -> OnboardingSuggestionView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> OnboardingSuggestionConfiguration {
        let calendar = Calendar.autoupdatingCurrent
        var dailyTotals: [Date: TimeInterval] = [:]

        for await activityData in data {
            for await segment in activityData.activitySegments {
                let day = calendar.startOfDay(
                    for: segment.dateInterval.start
                )
                dailyTotals[day, default: 0] += segment.totalActivityDuration
            }
        }

        let totalSeconds = dailyTotals.values.reduce(0, +)
        guard !dailyTotals.isEmpty, totalSeconds > 0 else {
            return .unavailable
        }

        let averageSource: [TimeInterval]
        if context == .mujoYearlyTotal || isSavingsContext {
            averageSource = dailyTotals
                .sorted { $0.key < $1.key }
                .suffix(OnboardingProjectionRules.recentDayCount)
                .map { $0.value }
        } else {
            averageSource = Array(dailyTotals.values)
        }
        let averageSeconds = averageSource.reduce(0, +)

        let averageMinutes = max(
            1,
            Int(
                (averageSeconds / Double(averageSource.count) / 60)
                    .rounded()
            )
        )
        let stepMinutes = OnboardingProjectionRules.limitStepMinutes
        let suggestedMinutes = max(
            OnboardingProjectionRules.minimumLimitMinutes,
            Int(
                (
                    Double(averageMinutes)
                        * OnboardingProjectionRules.suggestedLimitRatio
                        / Double(stepMinutes)
                )
                    .rounded()
            ) * stepMinutes
        )

        let dailyLimitMinutes = storedDailyLimitMinutes

        return OnboardingSuggestionConfiguration(
            totalMinutes: max(1, Int((totalSeconds / 60).rounded())),
            averageMinutes: averageMinutes,
            suggestedMinutes: suggestedMinutes,
            dailyLimitMinutes: dailyLimitMinutes,
            availableDayCount: dailyTotals.count
        )
    }

    private var storedDailyLimitMinutes: Int? {
        guard isSavingsContext || context == .mujoTodayUsage,
              let defaults = UserDefaults(
                suiteName: OnboardingReportStorage.appGroupIdentifier
              )
        else { return nil }

        let seconds = defaults.double(
            forKey: OnboardingReportStorage.dailyLimitSecondsKey
        )
        guard seconds > 0 else { return nil }
        return Int((seconds / 60).rounded())
    }

    private var isSavingsContext: Bool {
        context == .mujoDailySavings
            || context == .mujoWeeklySavings
            || context == .mujoAnnualSavings
    }
}
