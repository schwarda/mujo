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
    @StateObject private var screenTime: ScreenTimeManager
    @State private var isRequestingAuthorization = false
    @State private var sharedWindStrength = 0.0
    @State private var petalSimulationTime = 0.0
    @State private var petalFlow = SakuraPetalFlowState()
    @State private var petalsStartedDuringOnboarding = false
    @State private var hasResolvedInitialAuthorization = false
    @State private var isShowingLaunchOverlay = true
    private let firstLaunchLogoDuration = 1.6
    private let launchOverlayFadeDuration = 0.45
    @AppStorage("hasReachedScreenTimePermission")
    private var hasReachedScreenTimePermission = false
    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    init() {
        _screenTime = StateObject(wrappedValue: ScreenTimeManager())
    }

    init(screenTime: ScreenTimeManager) {
        _screenTime = StateObject(wrappedValue: screenTime)
    }

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
                await screenTime.recoverAfterAppUpdateIfNeeded()
                await NotificationAppDelegate.processPendingInvitationIfActive()
            }
        }
        .alert(
            "Screen Time Error",
            isPresented: Binding(
                get: {
                    hasCompletedOnboarding
                        && screenTime.errorMessage != nil
                },
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
        if isShowingLaunchOverlay || !hasResolvedInitialAuthorization {
            Color.clear
        } else if screenTime.isAuthorized && hasCompletedOnboarding {
            HomeScreen(
                screenTime: screenTime,
                windStrength: $sharedWindStrength,
                petalSimulationTime: $petalSimulationTime,
                petalFlow: $petalFlow,
                petalsStartFilled: !petalsStartedDuringOnboarding,
                showsPetals: screenTime.errorMessage == nil
            )
        } else if screenTime.isAuthorized {
            OnboardingLimitSetupView(
                screenTime: screenTime,
                windStrength: $sharedWindStrength,
                onCompleted: {
                    hasCompletedOnboarding = true
                }
            )
        } else if shouldShowPermissionExplanation {
            ScreenTimePermissionView(
                isRequestingAccess: isRequestingAuthorization,
                retry: requestScreenTimeAuthorization
            )
        } else {
            IntroductionView(
                isRequestingPermission: isRequestingAuthorization,
                petalSimulationTime: $petalSimulationTime,
                onCherryBlossomsStarted: {
                    petalsStartedDuringOnboarding = true
                },
                onContinue: requestScreenTimeAuthorization
            )
        }
    }

    @ViewBuilder
    private var launchOverlay: some View {
        if isShowingLaunchOverlay {
            ZStack {
                SakuraBackground()

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
        case .notDetermined, .approved:
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
            hasResolvedInitialAuthorization = true

            Task {
                await finishAuthorizedLaunch()
            }
        } else {
            hasResolvedInitialAuthorization = true
            Task {
                await finishOnboardingLaunch()
                await screenTime.recoverAfterAppUpdateIfNeeded()
            }
        }
    }

    private func finishOnboardingLaunch() async {
        try? await Task.sleep(for: .seconds(firstLaunchLogoDuration))
        guard !Task.isCancelled else { return }

        withAnimation(.easeInOut(duration: launchOverlayFadeDuration)) {
            isShowingLaunchOverlay = false
        }
    }

    private func finishAuthorizedLaunch() async {
        await Task.yield()
        withAnimation(.easeOut(duration: 0.2)) {
            isShowingLaunchOverlay = false
        }

        await screenTime.restoreMonitoringIfPossible()
        await screenTime.recoverAfterAppUpdateIfNeeded()
    }

    private func requestScreenTimeAuthorization() {
        guard !isRequestingAuthorization else { return }
        isRequestingAuthorization = true

        Task {
            await screenTime.requestAuthorizationAndStart()
            hasReachedScreenTimePermission = true
            isRequestingAuthorization = false
        }
    }
}

#Preview {
    ContentView()
}

#if DEBUG
#Preview("Screen Time Error") {
    let screenTime = ScreenTimeManager()
    ContentView(screenTime: screenTime)
        .onAppear {
            screenTime.showPreviewError(
                "Screen Time access could not be configured. Please try again."
            )
        }
}
#endif
