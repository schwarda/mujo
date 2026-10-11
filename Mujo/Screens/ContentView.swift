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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var screenTime: ScreenTimeManager
    @State private var isRequestingAuthorization = false
    @State private var sharedWindStrength = 0.0
    @State private var petalSimulationTime = 0.0
    @State private var petalFlow = SakuraPetalFlowState()
    @State private var petalsStartedDuringOnboarding = false
    @State private var hasResolvedInitialAuthorization = false
    @State private var isShowingLaunchOverlay = true
    @State private var showsOnboardingCompletionPetals = false
    @State private var onboardingCompletionProgress = 0.0
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
            if hasCompletedOnboarding {
                SakuraBackground()
                    .transition(.opacity)
            }

            if !hasCompletedOnboarding
                || showsOnboardingCompletionPetals {
                OnboardingBackground()
                    .onboardingCompletionMask(
                        isActive: showsOnboardingCompletionPetals,
                        progress: onboardingCompletionProgress
                    )
                    .transition(.opacity)
            }

            rootContent
                .transition(rootOnboardingMotionStyle.transition)
                .animation(
                    rootOnboardingMotionStyle.animation,
                    value: screenTime.authorizationStatus
                )
                .animation(
                    rootOnboardingMotionStyle.animation,
                    value: hasReachedScreenTimePermission
                )

            if showsOnboardingCompletionPetals {
                OnboardingSakuraCompletionView(
                    progress: onboardingCompletionProgress
                )
                    .transition(.opacity)
                    .zIndex(2)
            }

            launchOverlay
                .zIndex(3)
        }
        .task {
            await resolveInitialAuthorization()
        }
        .onChange(of: screenTime.authorizationStatus) { _, newStatus in
            guard newStatus != .notDetermined else { return }
            completeInitialSetup()
        }
        .onChange(of: scenePhase) { _, newPhase in
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
        if isShowingLaunchOverlay || !hasResolvedInitialAuthorization {
            Color.clear
        } else if screenTime.isAuthorized {
            ZStack {
                if hasCompletedOnboarding {
                    HomeScreen(
                        screenTime: screenTime,
                        windStrength: $sharedWindStrength,
                        petalSimulationTime: $petalSimulationTime,
                        petalFlow: $petalFlow,
                        petalsStartFilled: !petalsStartedDuringOnboarding,
                        showsPetals: screenTime.errorMessage == nil
                    )
                }

                if !hasCompletedOnboarding
                    || showsOnboardingCompletionPetals {
                    OnboardingLimitSetupView(
                        screenTime: screenTime,
                        onCompleted: completeOnboarding(using:)
                    )
                    .onboardingCompletionMask(
                        isActive: showsOnboardingCompletionPetals,
                        progress: onboardingCompletionProgress
                    )
                    .zIndex(1)
                }
            }
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

    private var rootOnboardingMotionStyle: OnboardingMotionStyle {
        reduceMotion ? .crossfade : .standard
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

        if hasCompletedOnboarding {
            await screenTime.restoreMonitoringIfPossible()
        }
        await screenTime.recoverAfterAppUpdateIfNeeded()
    }

    private func requestScreenTimeAuthorization() {
        guard !isRequestingAuthorization else { return }
        isRequestingAuthorization = true

        Task {
            await screenTime.requestAuthorization()
            hasReachedScreenTimePermission = true
            isRequestingAuthorization = false
        }
    }

    private func completeOnboarding(using style: OnboardingMotionStyle) {
        guard !showsOnboardingCompletionPetals else { return }

        guard style == .sakuraCompletion else {
            withAnimation(style.animation) {
                hasCompletedOnboarding = true
            }
            return
        }

        showsOnboardingCompletionPetals = true
        petalsStartedDuringOnboarding = true
        onboardingCompletionProgress = 0
        hasCompletedOnboarding = true

        Task { @MainActor in
            await Task.yield()
            withAnimation(OnboardingSakuraGust.animation) {
                onboardingCompletionProgress = 1
            }

            try? await Task.sleep(
                for: .seconds(OnboardingSakuraGust.animationDuration)
            )
            guard !Task.isCancelled else { return }

            showsOnboardingCompletionPetals = false
            onboardingCompletionProgress = 0
        }
    }
}

private struct OnboardingCompletionMaskModifier: ViewModifier {
    let isActive: Bool
    let progress: Double

    func body(content: Content) -> some View {
        let maskProgress = OnboardingCompletionMaskPolicy.progress(
            showsCompletionPetals: isActive,
            transitionProgress: progress
        )

        content.mask {
            OnboardingSakuraWipeMask(progress: maskProgress)
        }
    }
}

private extension View {
    func onboardingCompletionMask(
        isActive: Bool,
        progress: Double
    ) -> some View {
        modifier(OnboardingCompletionMaskModifier(
            isActive: isActive,
            progress: progress
        ))
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
