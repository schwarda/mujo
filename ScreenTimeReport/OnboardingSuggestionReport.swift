import DeviceActivity
import ExtensionKit
import Foundation
import SwiftUI

struct OnboardingSuggestionReport: nonisolated DeviceActivityReportScene {
    let context: DeviceActivityReport.Context
    let content: (
        OnboardingSuggestionConfiguration
    ) -> OnboardingReportContentView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> OnboardingSuggestionConfiguration {
        await configuration(representing: data)
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

        return OnboardingSuggestionCalculator.configuration(
            dailyTotals: dailyTotals,
            averageScope: usesRecentAverage ? .recentDays : .allAvailableDays,
            dailyLimitMinutes: storedDailyLimitMinutes
        )
    }

    private var usesRecentAverage: Bool {
        context == .mujoYearlyTotal
            || context == .mujoInsightsCarousel
            || isSavingsContext
    }

    private var storedDailyLimitMinutes: Int? {
        guard isSavingsContext,
              let defaults = UserDefaults(
                suiteName: AppConfiguration.appGroupIdentifier
              )
        else { return nil }

        let seconds = defaults.double(
            forKey: AppConfiguration.DefaultsKey.dailyLimit
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
