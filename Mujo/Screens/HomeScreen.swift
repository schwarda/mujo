//
//  HomeScreen.swift
//  Mujo
//
//  Created by Lopk Art on 06/09/2026.
//

import SwiftUI

struct HomeScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var screenTime: ScreenTimeManager

    @Binding var windStrength: Double
    @Binding var petalSimulationTime: Double
    @Binding var petalFlow: SakuraPetalFlowState
    let petalsStartFilled: Bool
    let showsPetals: Bool

    @State private var previewMinutes: Int?

    @AppStorage("wasNotificationPromptShown")
    private var wasNotificationPromptShown = false
    @State private var isShowingNotificationPrompt = false
    @StateObject private var notificationAuthorization = NotificationAuthorization()

    var body: some View {
        ZStack {
            VStack {
                remainingTimeView
                .frame(height: 170)
                .padding(.top, 64)

                Spacer()
            }

            if showsPetals {
                SakuraPetalField(
                    windStrength: windStrength,
                    startsFilled: petalsStartFilled,
                    simulationTime: $petalSimulationTime,
                    emitsPetals: shouldEmitPetals,
                    flowState: $petalFlow
                )
            }

            VStack {
                Spacer()

                Text("How much of today\nbelongs to a screen?")
                    .font(MujoTheme.italicFont(
                        size: 21,
                        relativeTo: .title3
                    ))
                    .tracking(0.4)
                    .lineSpacing(5)
                    .foregroundStyle(
                        .accent.opacity(MujoTheme.secondaryTextOpacity)
                    )
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)

                TimeDial(
                    minutes: Binding(
                        get: { selectedMinutes },
                        set: { previewMinutes = $0 }
                    ),
                    windStrength: $windStrength,
                    onValueChange: screenTime.previewDailyLimit
                ) { minutes in
                    Task {
                        await screenTime.setDailyLimit(minutes: minutes)
                        if previewMinutes == minutes {
                            previewMinutes = nil
                        }
                        
                        guard screenTime.isAuthorized,
                              screenTime.errorMessage == nil,
                              !wasNotificationPromptShown
                        else { return }

                        wasNotificationPromptShown = true
                        isShowingNotificationPrompt = true
                    }
                }
                .padding(.bottom, 80)
                
            }
        }
        .task {
            await refreshUsageWhileVisible()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            screenTime.refreshUsageSnapshot()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name.NSSystemTimeZoneDidChange
            )
        ) { _ in
            screenTime.refreshUsageSnapshot()
        }
        .alert("Let Mujø keep track", isPresented: $isShowingNotificationPrompt) {
            Button("Not now", role: .cancel) {}
            Button("Enable reminders") {
                Task {
                    await notificationAuthorization.requestAuthorization()
                }
            }
        } message: {
            Text(
                "You don't need to watch the clock. Mujø will remind you at "
                    + "meaningful moments, so you can stay aware without "
                    + "checking it yourself."
            )
        }
    }

    private var selectedMinutes: Int {
        previewMinutes ?? screenTime.dailyLimitMinutes
    }

    private var shouldEmitPetals: Bool {
        let estimate = screenTime.usageEstimate(
            forLimitMinutes: selectedMinutes
        )
        return !estimate.isAvailable || estimate.remainingTime > 0
    }

    @ViewBuilder
    private var remainingTimeView: some View {
        let estimate = screenTime.usageEstimate(
            forLimitMinutes: selectedMinutes
        )

        VStack {
            Text("R e m a i n i n g")
                .font(MujoTheme.mediumFont(
                    size: 12,
                    relativeTo: .caption2
                ))
                .textCase(.uppercase)
                .foregroundStyle(
                    MujoTheme.glassAccent.opacity(
                        MujoTheme.secondaryTextOpacity
                    )
                )

            if estimate.isAvailable {
                GlassText(value: estimate.remainingTime.formatted())
            } else {
                Text("Waiting for data")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(
                        MujoTheme.glassAccent.opacity(
                            MujoTheme.secondaryTextOpacity
                        )
                    )
            }
        }
        .padding()
    }

    private func refreshUsageWhileVisible() async {
        while !Task.isCancelled {
            if scenePhase == .active {
                screenTime.refreshUsageSnapshot()
            }

            try? await Task.sleep(for: .seconds(1))
        }
    }
}

private struct HomeScreenPreview: View {
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
