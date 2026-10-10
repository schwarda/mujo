import Foundation
import SwiftUI

#if DEBUG
struct HomeScreenPreview: View {
    @StateObject private var screenTime: ScreenTimeManager
    @State private var windStrength = 0.25
    @State private var petalSimulationTime = 0.0
    @State private var petalFlow = SakuraPetalFlowState()

    init() {
        let suiteName = "HomeScreenPreview"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)

        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(
            2 * 60 * 60,
            forKey: AppConfiguration.DefaultsKey.dailyLimit
        )
        defaults.set(
            45 * 60,
            forKey: AppConfiguration.DefaultsKey.estimatedUsedTime
        )
        defaults.set(
            today.timeIntervalSince1970,
            forKey: AppConfiguration.DefaultsKey.lastCheckpointResetDay
        )
        defaults.set(
            calendar.timeZone.identifier,
            forKey: AppConfiguration.DefaultsKey
                .lastCheckpointTimeZoneIdentifier
        )
        defaults.set(
            today.addingTimeInterval(-60).timeIntervalSince1970,
            forKey: AppConfiguration.DefaultsKey.usageMonitoringStartedAt
        )
        defaults.set(
            true,
            forKey: AppConfiguration.DefaultsKey.hasUsageCheckpoint
        )

        _screenTime = StateObject(
            wrappedValue: ScreenTimeManager(defaults: defaults)
        )
    }

    var body: some View {
        ZStack {
            SakuraBackground()

            HomeScreen(
                screenTime: screenTime,
                windStrength: $windStrength,
                petalSimulationTime: $petalSimulationTime,
                petalFlow: $petalFlow,
                petalsStartFilled: true,
                showsPetals: true
            )
        }
    }
}

#Preview("Home") {
    HomeScreenPreview()
}

#endif
