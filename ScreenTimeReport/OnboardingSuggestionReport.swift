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
#if DEBUG
        if isDiagnosticsContext {
            return diagnosticsConfiguration()
        }
#endif
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
        let isProductionSavingsContext = context == .mujoDailySavings
            || context == .mujoWeeklySavings
            || context == .mujoAnnualSavings
            || context == .mujoSavingsCarousel
#if DEBUG
        return isProductionSavingsContext
            || context == .mujoDiagnosticsSavingsCarousel
#else
        return isProductionSavingsContext
#endif
    }

#if DEBUG
    private var isDiagnosticsContext: Bool {
        context == .mujoDiagnosticsInsightsCarousel
            || context == .mujoDiagnosticsSavingsCarousel
    }

    private func diagnosticsConfiguration()
        -> OnboardingSuggestionConfiguration {
        guard let scenario = DiagnosticsScenarioStore
            .activeOnboardingScenario(),
              scenario != .noData
        else { return .unavailable }

        let calendar = Calendar.autoupdatingCurrent
        let end = calendar.startOfDay(for: .now)
        let reportedDayCount = min(
            scenario.historyDayCount,
            OnboardingProjectionRules.recentDayCount
        )
        let firstHistoryDayNumber = scenario.historyDayCount
            - reportedDayCount + 1
        var dailyTotals: [Date: TimeInterval] = [:]

        for index in 0..<reportedDayCount {
            guard let day = calendar.date(
                byAdding: .day,
                value: index - reportedDayCount,
                to: end
            ) else { continue }
            let historyDayNumber = firstHistoryDayNumber + index
            dailyTotals[day] = TimeInterval(historyDayNumber * 60 * 60)
        }

        return OnboardingSuggestionCalculator.configuration(
            dailyTotals: dailyTotals,
            averageScope: .recentDays,
            dailyLimitMinutes: storedDailyLimitMinutes
        )
    }
#endif
}
