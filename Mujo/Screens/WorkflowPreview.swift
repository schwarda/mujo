import Combine
import SwiftUI

#if DEBUG
struct WorkflowPreview: View {
    @StateObject private var session = WorkflowPreviewSession()

    var body: some View {
        ContentView(screenTime: session.screenTime)
            .defaultAppStorage(session.defaults)
    }
}

@MainActor
private final class WorkflowPreviewSession: ObservableObject {
    private let suiteName = "Mujo.WorkflowPreview.\(UUID().uuidString)"
    let defaults: UserDefaults
    let screenTime: ScreenTimeManager

    init() {
        // A named suite is required so demo state stays outside the app's stores.
        defaults = UserDefaults(suiteName: suiteName)!
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        defaults.set(45 * 60, forKey: AppConfiguration.DefaultsKey.estimatedUsedTime)
        defaults.set(
            today.timeIntervalSince1970,
            forKey: AppConfiguration.DefaultsKey.lastCheckpointResetDay
        )
        defaults.set(
            calendar.timeZone.identifier,
            forKey: AppConfiguration.DefaultsKey.lastCheckpointTimeZoneIdentifier
        )
        defaults.set(
            today.addingTimeInterval(-60).timeIntervalSince1970,
            forKey: AppConfiguration.DefaultsKey.usageMonitoringStartedAt
        )
        defaults.set(true, forKey: AppConfiguration.DefaultsKey.hasUsageCheckpoint)
        screenTime = ScreenTimeManager(workflowDefaults: defaults)
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }
}

enum WorkflowPreviewData {
    static func report(limitMinutes: Int) -> OnboardingSuggestionConfiguration {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        var dailyTotals: [Date: TimeInterval] = [:]
        for offset in 1...OnboardingProjectionRules.recentDayCount {
            if let day = calendar.date(byAdding: .day, value: -offset, to: today) {
                dailyTotals[day] = TimeInterval(OnboardingPreviewData.dailyAverageMinutes * 60)
            }
        }
        return OnboardingSuggestionCalculator.configuration(
            dailyTotals: dailyTotals,
            averageScope: .recentDays,
            dailyLimitMinutes: limitMinutes
        )
    }
}

#Preview("Full Workflow") {
    WorkflowPreview()
}
#endif
