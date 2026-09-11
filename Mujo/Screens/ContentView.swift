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
    @State private var canLoadActivityReport = false
    @AppStorage("hasReachedScreenTimePermission")
    private var hasReachedScreenTimePermission = false
    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            SakuraBackground()
            rootContent
            launchOverlay
        }
        .task {
            await resolveInitialAuthorization()
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

    @ViewBuilder
    private var rootContent: some View {
        if !hasResolvedInitialAuthorization {
            Color.clear
        } else if screenTime.isAuthorized {
            authorizedTabs
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

    private var authorizedTabs: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                    .tag(tab)
            }
        }
        .tint(.accentColor)
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            HomeScreen(
                screenTime: screenTime,
                windStrength: $sharedWindStrength,
                petalSimulationTime: $petalSimulationTime,
                petalsStartFilled: !petalsStartedDuringOnboarding,
                canLoadActivityReport: canLoadActivityReport
            )
        case .history:
            HistoryScreen(
                petalSimulationTime: $petalSimulationTime,
                petalsStartFilled: !petalsStartedDuringOnboarding
            )
        }
    }

    @ViewBuilder
    private var launchOverlay: some View {
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

    private func resolveInitialAuthorization() async {
        screenTime.refreshAuthorizationStatus()
        let hasRequestedAuthorization = hasCompletedOnboarding
            || hasReachedScreenTimePermission

        if screenTime.authorizationStatus != .notDetermined
            || !hasRequestedAuthorization {
            completeInitialSetup()
            return
        }

        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else { return }
        screenTime.refreshAuthorizationStatus()
        completeInitialSetup()
    }

    private func completeInitialSetup() {
        guard !hasResolvedInitialAuthorization else { return }

        if screenTime.isAuthorized {
            hasCompletedOnboarding = true
            let activityReportRequestID = screenTime.beginActivityReportLoad()
            canLoadActivityReport = true
            hasResolvedInitialAuthorization = true

            Task {
                await finishAuthorizedLaunch(
                    activityReportRequestID: activityReportRequestID
                )
            }
        } else {
            hasResolvedInitialAuthorization = true
            isShowingLaunchOverlay = false
            canLoadActivityReport = true
        }
    }

    private func finishAuthorizedLaunch(
        activityReportRequestID: String
    ) async {
        await screenTime.waitUntilActivityReportIsReady(
            requestID: activityReportRequestID
        )
        guard !Task.isCancelled else { return }
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

#Preview {
    ContentView()
}
