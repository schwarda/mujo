import SwiftUI

#if DEBUG
// Canvas-only fixtures. These never change the running app's diagnostic scenario.
private enum OnboardingReportPreviewScenario {
    case noData
    case oneDay
    case threeDays
    case sevenDays

    var configuration: OnboardingSuggestionConfiguration {
        let dayCount: Int
        switch self {
        case .noData: dayCount = 0
        case .oneDay: dayCount = 1
        case .threeDays: dayCount = 3
        case .sevenDays: dayCount = 7
        }

        let calendar = Calendar(identifier: .gregorian)
        let end = Date(timeIntervalSince1970: 1_783_036_800)
        var dailyTotals: [Date: TimeInterval] = [:]
        for index in 0..<dayCount {
            let day = calendar.date(byAdding: .day, value: index - dayCount, to: end)!
            // A consistent 3h baseline makes the effect of history length clear.
            dailyTotals[day] = 3 * 60 * 60
        }
        return OnboardingSuggestionCalculator.configuration(
            dailyTotals: dailyTotals,
            averageScope: .recentDays,
            dailyLimitMinutes: 150
        )
    }
}

private struct OnboardingReportScenarioPreview: View {
    let scenario: OnboardingReportPreviewScenario
    let step: OnboardingStep

    var body: some View {
        OnboardingLimitSetupView(
            previewStep: step,
            reportPreviewConfiguration: scenario.configuration
        )
        .tint(MujoTheme.brandAccent)
    }
}

#Preview("Insights · No data") {
    OnboardingReportScenarioPreview(scenario: .noData, step: .insights)
}

#Preview("Savings · No data") {
    OnboardingReportScenarioPreview(scenario: .noData, step: .savings)
}

#Preview("Insights · 1 day") {
    OnboardingReportScenarioPreview(scenario: .oneDay, step: .insights)
}

#Preview("Savings · 1 day") {
    OnboardingReportScenarioPreview(scenario: .oneDay, step: .savings)
}

#Preview("Insights · 3 days") {
    OnboardingReportScenarioPreview(scenario: .threeDays, step: .insights)
}

#Preview("Savings · 3 days") {
    OnboardingReportScenarioPreview(scenario: .threeDays, step: .savings)
}

#Preview("Insights · 7 days") {
    OnboardingReportScenarioPreview(scenario: .sevenDays, step: .insights)
}

#Preview("Savings · 7 days") {
    OnboardingReportScenarioPreview(scenario: .sevenDays, step: .savings)
}

#endif
