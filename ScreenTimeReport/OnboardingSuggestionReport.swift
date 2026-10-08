import DeviceActivity
import ExtensionKit
import Foundation
import SwiftUI

struct OnboardingSuggestionConfiguration {
    let totalMinutes: Int?
    let recentTotalMinutes: Int?
    let averageMinutes: Int?
    let suggestedMinutes: Int?
    let dailyLimitMinutes: Int?
    let availableDayCount: Int
    let recentAvailableDayCount: Int

    static let unavailable = Self(
        totalMinutes: nil,
        recentTotalMinutes: nil,
        averageMinutes: nil,
        suggestedMinutes: nil,
        dailyLimitMinutes: nil,
        availableDayCount: 0,
        recentAvailableDayCount: 0
    )
}

struct OnboardingSuggestionReport: nonisolated DeviceActivityReportScene {
    let context: DeviceActivityReport.Context
    let content: (
        OnboardingSuggestionConfiguration
    ) -> OnboardingReportContentView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> OnboardingSuggestionConfiguration {
#if DEBUG
        let startedAt = PerformanceDiagnostics.now
        PerformanceDiagnostics.log(
            "report-extension",
            "makeConfiguration started; context=\(context.rawValue)"
        )
#endif
        let result = await configuration(representing: data)
#if DEBUG
        PerformanceDiagnostics.log(
            "report-extension",
            "makeConfiguration finished; context=\(context.rawValue), elapsed=\(PerformanceDiagnostics.elapsedMilliseconds(since: startedAt)) ms, days=\(result.availableDayCount), recentDays=\(result.recentAvailableDayCount), total=\(String(describing: result.totalMinutes)), average=\(String(describing: result.averageMinutes))"
        )
#endif
        return result
    }

    private func configuration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> OnboardingSuggestionConfiguration {
        let calendar = Calendar.autoupdatingCurrent
        var dailyTotals: [Date: TimeInterval] = [:]

        for await activityData in data {
            guard !Task.isCancelled else { return .unavailable }
            for await segment in activityData.activitySegments {
                guard !Task.isCancelled else { return .unavailable }
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

        let recentSource = dailyTotals
            .sorted { $0.key < $1.key }
            .suffix(OnboardingProjectionRules.recentDayCount)
            .map { $0.value }
        let averageSource: [TimeInterval]
        if context == .mujoYearlyTotal
            || context == .mujoInsightsCarousel
            || isSavingsContext {
            averageSource = recentSource
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

    private var storedDailyLimitMinutes: Int? {
        guard isSavingsContext,
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
            || context == .mujoSavingsCarousel
    }
}
