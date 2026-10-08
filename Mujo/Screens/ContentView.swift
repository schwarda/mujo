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
#if DEBUG
        let startedAt = PerformanceDiagnostics.now
#endif
        _screenTime = StateObject(wrappedValue: ScreenTimeManager())
#if DEBUG
        PerformanceDiagnostics.log(
            "content",
            "ContentView initialized in \(PerformanceDiagnostics.elapsedMilliseconds(since: startedAt)) ms"
        )
#endif
    }

    init(screenTime: ScreenTimeManager) {
        _screenTime = StateObject(wrappedValue: screenTime)
#if DEBUG
        PerformanceDiagnostics.log(
            "content",
            "ContentView initialized with supplied ScreenTimeManager"
        )
#endif
    }

    var body: some View {
#if DEBUG
        let _ = PerformanceDiagnostics.throttledLog(
            key: "ContentView.body",
            "swiftui-body",
            "ContentView body; resolvedAuth=\(hasResolvedInitialAuthorization), launchOverlay=\(isShowingLaunchOverlay), authorized=\(screenTime.isAuthorized), completedOnboarding=\(hasCompletedOnboarding)"
        )
#endif
        ZStack {
            if hasCompletedOnboarding {
                SakuraBackground()
            } else {
                OnboardingBackground()
            }
            rootContent
            launchOverlay
        }
        .task {
#if DEBUG
            PerformanceDiagnostics.log("content", "initial authorization task started")
#endif
            await resolveInitialAuthorization()
        }
        .onAppear {
#if DEBUG
            PerformanceDiagnostics.markPhase("content.appeared")
            PerformanceDiagnostics.log("content", "ContentView appeared")
#endif
        }
        .onChange(of: screenTime.authorizationStatus) { oldStatus, newStatus in
#if DEBUG
            PerformanceDiagnostics.log(
                "content",
                "authorization changed \(String(describing: oldStatus)) -> \(String(describing: newStatus))"
            )
            PerformanceDiagnostics.markPhase("authorization.changed")
#endif
            guard newStatus != .notDetermined else { return }
            completeInitialSetup()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
#if DEBUG
            PerformanceDiagnostics.log(
                "app-lifecycle",
                "scene phase \(String(describing: oldPhase)) -> \(String(describing: newPhase))"
            )
#endif
            guard newPhase == .active, hasCompletedOnboarding else { return }
            Task {
                await screenTime.restoreMonitoringIfPossible()
                await screenTime.recoverAfterAppUpdateIfNeeded()
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
#if DEBUG
        let _ = PerformanceDiagnostics.throttledLog(
            key: "ContentView.rootContent",
            "swiftui-body",
            "rootContent; overlay=\(isShowingLaunchOverlay), resolvedAuth=\(hasResolvedInitialAuthorization), authorized=\(screenTime.isAuthorized), completed=\(hasCompletedOnboarding)"
        )
#endif
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
#if DEBUG
        let startedAt = PerformanceDiagnostics.now
        PerformanceDiagnostics.log("content", "resolveInitialAuthorization started")
#endif
        screenTime.refreshAuthorizationStatus()
        let hasRequestedAuthorization = hasCompletedOnboarding
            || hasReachedScreenTimePermission

        if screenTime.authorizationStatus != .notDetermined
            || !hasRequestedAuthorization {
            completeInitialSetup()
#if DEBUG
            PerformanceDiagnostics.log(
                "content",
                "resolveInitialAuthorization completed immediately in \(PerformanceDiagnostics.elapsedMilliseconds(since: startedAt)) ms"
            )
#endif
            return
        }

        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else { return }
        screenTime.refreshAuthorizationStatus()
        completeInitialSetup()
#if DEBUG
        PerformanceDiagnostics.log(
            "content",
            "resolveInitialAuthorization completed after retry in \(PerformanceDiagnostics.elapsedMilliseconds(since: startedAt)) ms"
        )
#endif
    }

    private func completeInitialSetup() {
#if DEBUG
        let startedAt = PerformanceDiagnostics.now
        PerformanceDiagnostics.log(
            "content",
            "completeInitialSetup entered; alreadyResolved=\(hasResolvedInitialAuthorization), authorized=\(screenTime.isAuthorized)"
        )
#endif
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
#if DEBUG
        PerformanceDiagnostics.log(
            "content",
            "completeInitialSetup returned in \(PerformanceDiagnostics.elapsedMilliseconds(since: startedAt)) ms"
        )
#endif
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

        if hasCompletedOnboarding {
            await screenTime.restoreMonitoringIfPossible()
        }
        await screenTime.recoverAfterAppUpdateIfNeeded()
    }

    private func requestScreenTimeAuthorization() {
        guard !isRequestingAuthorization else { return }
#if DEBUG
        let startedAt = PerformanceDiagnostics.now
        PerformanceDiagnostics.markPhase("authorization.request.started")
        PerformanceDiagnostics.log("content", "Screen Time authorization requested")
#endif
        isRequestingAuthorization = true

        Task {
            await screenTime.requestAuthorization()
#if DEBUG
            PerformanceDiagnostics.log(
                "content",
                "Screen Time authorization returned in \(PerformanceDiagnostics.elapsedMilliseconds(since: startedAt)) ms; status=\(String(describing: screenTime.authorizationStatus))"
            )
            PerformanceDiagnostics.markPhase("authorization.request.returned")
#endif
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
