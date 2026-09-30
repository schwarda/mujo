//
//  HomeScreen.swift
//  Mujo
//
//  Created by Lopk Art on 06/09/2026.
//

import DeviceActivity
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
    @State private var isShowingLimitEditor = false

#if DEBUG
    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = true
#endif

    var body: some View {
        ZStack {
            DeviceActivityReport(
                .mujoLimitEditorDescription,
                filter: sevenDayReportFilter
            )
            .frame(width: 1, height: 1)
            .opacity(0.001)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            VStack {
                remainingTimeView
                .frame(height: 200)
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

                Button {
                    isShowingLimitEditor = true
                } label: {
                    HStack(spacing: 6) {
                        Text("Change daily limit")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .font(MujoTheme.mediumFont(size: 17, relativeTo: .body))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 20)
                    .frame(height: 50)
                    .contentShape(Capsule())
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .shadow(
                    color: MujoTheme.brandAccent.opacity(0.34),
                    radius: 14,
                    y: 8
                )
                .padding(.bottom, 80)
                
            }

#if DEBUG
            VStack {
                HStack {
                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasCompletedOnboarding = false
                        }
                    } label: {
                        Label(
                            "Replay onboarding",
                            systemImage: "arrow.counterclockwise"
                        )
                    }
                    .buttonStyle(.glass)
                    .foregroundStyle(.tint)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
#endif
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
        .sheet(isPresented: $isShowingLimitEditor) {
            DailyLimitEditorScreen(
                screenTime: screenTime,
                windStrength: $windStrength
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var selectedMinutes: Int {
        previewMinutes ?? screenTime.dailyLimitMinutes
    }

    private var sevenDayReportFilter: DeviceActivityFilter {
        let calendar = Calendar.autoupdatingCurrent
        let end = calendar.startOfDay(for: .now)
        let start = calendar.date(
            byAdding: .day,
            value: -OnboardingProjectionRules.recentDayCount,
            to: end
        ) ?? end

        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: end)),
            users: .all,
            devices: .all
        )
    }

    private var todayReportFilter: DeviceActivityFilter {
        let start = Calendar.autoupdatingCurrent.startOfDay(for: .now)
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: .now)),
            users: .all,
            devices: .all
        )
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

        VStack(spacing: 6) {
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
                        .fixedSize(horizontal: true, vertical: true)
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

            DeviceActivityReport(
                .mujoTodayUsage,
                filter: todayReportFilter
            )
            .frame(height: 24)
            .padding(.horizontal, 12)
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

private struct DailyLimitEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var screenTime: ScreenTimeManager
    @Binding var windStrength: Double

    @State private var selectedMinutes: Int
    @State private var isSaving = false
    @State private var shouldLoadUsageReport = false
    private let originalLimitMinutes: Int

    init(
        screenTime: ScreenTimeManager,
        windStrength: Binding<Double>
    ) {
        self.screenTime = screenTime
        _windStrength = windStrength
        _selectedMinutes = State(initialValue: screenTime.dailyLimitMinutes)
        originalLimitMinutes = screenTime.dailyLimitMinutes
    }

    var body: some View {
        ZStack {
            SakuraBackground()

            VStack(spacing: 0) {

                Text("Choose your\ndaily limit")
                    .font(MujoTheme.boldFont(size: 40, relativeTo: .largeTitle))
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)

                Group {
                    if shouldLoadUsageReport {
                        DeviceActivityReport(
                            .mujoLimitEditorDescription,
                            filter: sevenDayReportFilter
                        )
                    } else {
                        ProgressView("Loading Screen Time…")
                            .font(MujoTheme.italicFont(
                                size: 17,
                                relativeTo: .body
                            ))
                            .foregroundStyle(
                                .tint.opacity(MujoTheme.secondaryTextOpacity)
                            )
                    }
                }
                .frame(height: 64)
                .padding(.horizontal, 24)
                .padding(.top, 32)

                Spacer(minLength: 18)

                Text(formattedLimit)
                    .font(.system(size: 88, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.tint)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)

                Text("new daily limit")
                    .font(MujoTheme.italicFont(size: 18, relativeTo: .body))
                    .foregroundStyle(
                        .tint.opacity(MujoTheme.secondaryTextOpacity)
                    )
                    .padding(.top, -8)

                TimeDial(
                    minutes: $selectedMinutes,
                    windStrength: $windStrength,
                    showsValue: false,
                    onValueChange: screenTime.previewDailyLimit,
                    onCommit: { _ in }
                )
                .padding(.top, 40)
                
                Spacer(minLength: 18)

                OnboardingPrimaryButton(isDisabled: isSaving) {
                    saveLimit()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Set limit")
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
        .interactiveDismissDisabled(isSaving)
        .task {
            // Let the sheet complete its first presentation frame before the
            // system starts the comparatively expensive report extension.
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            shouldLoadUsageReport = true
        }
        .onDisappear {
            guard !isSaving else { return }
            screenTime.cancelDailyLimitPreview()
        }
    }

    private var sevenDayReportFilter: DeviceActivityFilter {
        let calendar = Calendar.autoupdatingCurrent
        let end = calendar.startOfDay(for: .now)
        let start = calendar.date(
            byAdding: .day,
            value: -OnboardingProjectionRules.recentDayCount,
            to: end
        ) ?? end

        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: end)),
            users: .all,
            devices: .all
        )
    }

    private var formattedLimit: String {
        let hours = selectedMinutes / 60
        let minutes = selectedMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }

    private var formattedOriginalLimit: String {
        let hours = originalLimitMinutes / 60
        let minutes = originalLimitMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }

    private func saveLimit() {
        guard !isSaving else { return }
        isSaving = true

        Task {
            await screenTime.setDailyLimit(minutes: selectedMinutes)
            isSaving = false
            guard screenTime.errorMessage == nil else { return }
            dismiss()
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
