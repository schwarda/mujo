import DeviceActivity
import ExtensionKit
import SwiftUI

@main
struct ScreenTimeReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        OnboardingSuggestionReport(context: .mujoInsightsCarousel) {
            configuration in
            OnboardingReportContentView(
                configuration: configuration,
                presentation: .insightsCarousel
            )
        }

        OnboardingSuggestionReport(context: .mujoDailyAverage) {
            configuration in
            OnboardingReportContentView(
                configuration: configuration,
                presentation: .dailyAverage
            )
        }

        OnboardingSuggestionReport(context: .mujoWeeklyTotal) {
            configuration in
            OnboardingReportContentView(
                configuration: configuration,
                presentation: .weeklyTotal
            )
        }

        OnboardingSuggestionReport(context: .mujoYearlyTotal) {
            configuration in
            OnboardingReportContentView(
                configuration: configuration,
                presentation: .yearlyTotal
            )
        }

        OnboardingSuggestionReport(context: .mujoLimitEditorDescription) {
            configuration in
            OnboardingReportContentView(
                configuration: configuration,
                presentation: .limitEditorDescription
            )
        }

        OnboardingSuggestionReport(context: .mujoDailySavings) {
            configuration in
            OnboardingReportContentView(
                configuration: configuration,
                presentation: .dailySavings
            )
        }

        OnboardingSuggestionReport(context: .mujoWeeklySavings) {
            configuration in
            OnboardingReportContentView(
                configuration: configuration,
                presentation: .weeklySavings
            )
        }

        OnboardingSuggestionReport(context: .mujoAnnualSavings) {
            configuration in
            OnboardingReportContentView(
                configuration: configuration,
                presentation: .annualSavings
            )
        }

        OnboardingSuggestionReport(context: .mujoSavingsCarousel) {
            configuration in
            OnboardingReportContentView(
                configuration: configuration,
                presentation: .savingsCarousel
            )
        }

    }
}
