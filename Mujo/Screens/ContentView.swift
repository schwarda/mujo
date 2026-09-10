//
//  ContentView.swift
//  Mujo
//
//  Created by Aikari Studio on 05/09/2026.
//

import SwiftUI
import FamilyControls

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var screenTime = ScreenTimeManager()
    @State private var selectedTab: AppTab = .home
    @State private var isRequestingAuthorization = false
    @State private var sharedWindStrength = 0.0
    @State private var petalSimulationTime = 0.0
    @State private var petalsStartedDuringOnboarding = false
    @State private var hasResolvedInitialAuthorization = false
    @State private var isShowingLaunchOverlay = true
    @AppStorage("hasReachedScreenTimePermission")
    private var hasReachedScreenTimePermission = false
    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            SakuraBackground()

            Group {
                if !hasResolvedInitialAuthorization {
                    Color.clear
                } else if screenTime.isAuthorized {
                    TabView(selection: $selectedTab) {
                        ForEach(AppTab.allCases) { tab in
                            Group {
                                switch tab {
                                case .home:
                                    HomeScreen(
                                        screenTime: screenTime,
                                        windStrength: $sharedWindStrength,
                                        petalSimulationTime: $petalSimulationTime,
                                        petalsStartFilled: !petalsStartedDuringOnboarding
                                    )
                                case .history:
                                    HistoryScreen(
                                        petalSimulationTime: $petalSimulationTime,
                                        petalsStartFilled: !petalsStartedDuringOnboarding
                                    )
                                }
                            }
                            .tabItem {
                                Label(tab.title, systemImage: tab.systemImage)
                            }
                            .tag(tab)
                        }
                    }
                    .tint(.accentColor)
                } else if shouldShowPermissionExplanation {
                    ScreenTimePermissionView(
                        petalSimulationTime: $petalSimulationTime,
                        petalsStartFilled: !petalsStartedDuringOnboarding,
                        retry: requestScreenTimeAuthorization
                    )
                } else {
                    FirstScreen(
                        isRequestingPermission: isRequestingAuthorization,
                        petalSimulationTime: $petalSimulationTime,
                        onCherryBlossomsStarted: {
                            petalsStartedDuringOnboarding = true
                        },
                        onContinue: requestScreenTimeAuthorization
                    )
                }
            }

            if isShowingLaunchOverlay {
                ZStack {
                    Color("LaunchBackground")
                        .ignoresSafeArea()

                    Image("LaunchLogo")
                        .frame(width: 160, height: 160)
                }
                .transition(.opacity)
                .accessibilityHidden(true)
                .zIndex(1)
            }

        }
        .task {
            screenTime.refreshAuthorizationStatus()
            let hasRequestedAuthorization = hasCompletedOnboarding
                || hasReachedScreenTimePermission

            if screenTime.authorizationStatus != .notDetermined
                || !hasRequestedAuthorization {
                completeInitialSetup()
            } else {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                screenTime.refreshAuthorizationStatus()
                completeInitialSetup()
            }
        }
        .onChange(of: screenTime.authorizationStatus) { _, newStatus in
            guard newStatus != .notDetermined else { return }
            completeInitialSetup()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await screenTime.restoreMonitoringIfPossible()
            }
        }
        .alert(
            "Screen Time Error",
            isPresented: Binding(
                get: { screenTime.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        screenTime.clearError()
                    }
                }
            )
        ) {
            Button("OK") {
                screenTime.clearError()
            }
        } message: {
            Text(screenTime.errorMessage ?? "Please try again.")
        }
    }

    private var shouldShowPermissionExplanation: Bool {
        if hasCompletedOnboarding || hasReachedScreenTimePermission {
            return true
        }

        switch screenTime.authorizationStatus {
        case .denied:
            return true
        case .notDetermined, .approved, .approvedWithDataAccess:
            return false
        default:
            return true
        }
    }

    private func completeInitialSetup() {
        guard !hasResolvedInitialAuthorization else { return }

        if screenTime.isAuthorized {
            hasCompletedOnboarding = true
            hasResolvedInitialAuthorization = true

            Task {
                await finishAuthorizedLaunch()
            }
        } else {
            hasResolvedInitialAuthorization = true
            isShowingLaunchOverlay = false
        }
    }

    private func finishAuthorizedLaunch() async {
        await Task.yield()
        withAnimation(.easeOut(duration: 0.2)) {
            isShowingLaunchOverlay = false
        }

        await screenTime.restoreMonitoringIfPossible()
    }

    private func requestScreenTimeAuthorization() {
        guard !isRequestingAuthorization else { return }
        isRequestingAuthorization = true

        Task {
            await screenTime.requestAuthorizationAndStart()
            hasReachedScreenTimePermission = true
            if screenTime.isAuthorized {
                hasCompletedOnboarding = true
            }
            isRequestingAuthorization = false
        }
    }
}

private struct ScreenTimePermissionView: View {
    @Binding var petalSimulationTime: Double
    let petalsStartFilled: Bool
    let retry: () -> Void

    var body: some View {
        ZStack {
            SakuraPetalField(
                windStrength: 0,
                startsFilled: petalsStartFilled,
                simulationTime: $petalSimulationTime
            )

            VStack(spacing: 18) {
                Image(systemName: "hourglass")
                    .font(.system(size: 46, weight: .medium))
                    .foregroundStyle(.tint)

                Text("Screen Time access is required")
                    .font(.title3.weight(.semibold))

                Text("Mujø needs permission to calculate how much time remains today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Allow Access", action: retry)
                    .buttonStyle(.glass)
            }
            .padding(32)
        }
    }
}

#Preview {
    ContentView()
}
