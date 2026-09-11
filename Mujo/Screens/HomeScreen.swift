//
//  HomeScreen.swift
//  Mujo
//
//  Created by Lopk Art on 06/09/2026.
//

import SwiftUI
import DeviceActivity

struct HomeScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var screenTime: ScreenTimeManager
    @Binding var windStrength: Double
    @Binding var petalSimulationTime: Double
    let petalsStartFilled: Bool
    let canLoadActivityReport: Bool
    @State private var selectedMinutes = Int(
        AppConfiguration.defaultDailyLimit / 60
    )
    @State private var shouldLoadReport = false
    @State private var reportInterval = LocalDayInterval.containing(.now)

    var body: some View {
        ZStack {
            VStack {
                Group {
                    if shouldLoadReport {
                        DeviceActivityReport(
                            .mujoToday,
                            filter: screenTime.reportFilter(for: reportInterval)
                        )
                    } else {
                        Color.clear
                    }
                }
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
                    }
                }
                .padding(.bottom, 80)
            }
        }
        .task {
            selectedMinutes = screenTime.dailyLimitMinutes
        }
        .task(id: canLoadActivityReport) {
            guard canLoadActivityReport else { return }
            await Task.yield()
            shouldLoadReport = true
        }
        .task {
            await refreshReportAtDayBoundaries()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshReportIfNeeded()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name.NSSystemTimeZoneDidChange
            )
        ) { _ in
            refreshReportIfNeeded()
        }
    }

    private func refreshReportAtDayBoundaries() async {
        while !Task.isCancelled {
            let now = Date.now
            let nextDay = LocalDayInterval.containing(now).end
            let delay = max(1, nextDay.timeIntervalSince(now))

            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }

            refreshReportIfNeeded()
        }
    }

    private func refreshReportIfNeeded(at date: Date = .now) {
        let currentInterval = LocalDayInterval.containing(date)
        guard currentInterval != reportInterval else { return }

        reportInterval = currentInterval
    }
}

#Preview {
    ContentView()
}
