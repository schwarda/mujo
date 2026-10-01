import DeviceActivity
import ExtensionKit
import SwiftUI

@main
struct ScreenTimeReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        OnboardingSuggestionReport(context: .mujoDailyAverage) {
            configuration in
            OnboardingSuggestionView(
                configuration: configuration,
                presentation: .dailyAverage
            )
        }

        OnboardingSuggestionReport(context: .mujoWeeklyTotal) {
            configuration in
            OnboardingSuggestionView(
                configuration: configuration,
                presentation: .weeklyTotal
            )
        }

        OnboardingSuggestionReport(context: .mujoYearlyTotal) {
            configuration in
            OnboardingSuggestionView(
                configuration: configuration,
                presentation: .yearlyTotal
            )
        }

        OnboardingSuggestionReport(context: .mujoLimitPrompt) {
            configuration in
            OnboardingSuggestionView(
                configuration: configuration,
                presentation: .limitPrompt
            )
        }

        OnboardingSuggestionReport(context: .mujoLimitEditorDescription) {
            configuration in
            OnboardingSuggestionView(
                configuration: configuration,
                presentation: .limitEditorDescription
            )
        }

        OnboardingSuggestionReport(context: .mujoDailySavings) {
            configuration in
            OnboardingSuggestionView(
                configuration: configuration,
                presentation: .dailySavings
            )
        }

        OnboardingSuggestionReport(context: .mujoWeeklySavings) {
            configuration in
            OnboardingSuggestionView(
                configuration: configuration,
                presentation: .weeklySavings
            )
        }

        OnboardingSuggestionReport(context: .mujoAnnualSavings) {
            configuration in
            OnboardingSuggestionView(
                configuration: configuration,
                presentation: .annualSavings
            )
        }

    }
}
