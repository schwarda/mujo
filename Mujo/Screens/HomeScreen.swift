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
    let petalsStartFilled: Bool

    @State private var selectedMinutes = Int(
        AppConfiguration.defaultDailyLimit / 60
    )

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

            SakuraPetalField(
                windStrength: windStrength,
                startsFilled: petalsStartFilled,
                simulationTime: $petalSimulationTime
            )

            VStack {
                Spacer()

                Text("How much of today\nbelongs to a screen?")
                    .font(MujoTheme.mediumFont(
                        size: 22,
                        relativeTo: .title3
                    ))
                    .foregroundStyle(
                        .accent.opacity(MujoTheme.secondaryTextOpacity)
                    )
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)

                TimeDial(
                    minutes: $selectedMinutes,
                    windStrength: $windStrength,
                    onValueChange: screenTime.previewDailyLimit
                ) { minutes in
                    Task {
                        await screenTime.setDailyLimit(minutes: minutes)
                        
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
            selectedMinutes = screenTime.dailyLimitMinutes
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
        .alert("Stay on track?", isPresented: $isShowingNotificationPrompt) {
            Button("Not now", role: .cancel) {}
            Button("Enable reminders") {
                Task {
                    await notificationAuthorization.requestAuthorization()
                }
            }
        } message: {
            Text("Get reminders at 50%, 75%, and when 30 minutes remain.")
        }
    }

    @ViewBuilder
    private var remainingTimeView: some View {
        let estimate = screenTime.usageEstimate(
            forLimitMinutes: selectedMinutes
        )

        VStack {
            Text("Remaining")
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
                    .font(.headline)
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

#Preview {
    ContentView()
}
