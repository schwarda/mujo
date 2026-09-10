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
    @State private var selectedMinutes = 5 * 60

    var body: some View {

        ZStack {
            VStack {
                DeviceActivityReport(
                    .mujoToday,
                    filter: screenTime.reportFilter
                )
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
                    .font(.custom(
                        "AvenirNext-Medium",
                        size: 22,
                        relativeTo: .title3
                    ))
                    .foregroundStyle(.accent.opacity(0.72))
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
            screenTime.restoreMonitoringIfPossible()
            selectedMinutes = screenTime.dailyLimitMinutes
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            screenTime.restoreMonitoringIfPossible()
        }
    }
}

#Preview {
    ContentView()
}
