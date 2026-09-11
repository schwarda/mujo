//
//  HomeScreen.swift
//  Mujo
//
//  Created by Lopk Art on 06/09/2026.
//

import SwiftUI
import DeviceActivity

struct HomeScreen: View {
    @ObservedObject var screenTime: ScreenTimeManager
    @Binding var windStrength: Double
    @Binding var petalSimulationTime: Double
    let petalsStartFilled: Bool
    let canLoadActivityReport: Bool
    @State private var selectedMinutes = Int(
        AppConfiguration.defaultDailyLimit / 60
    )
    @State private var shouldLoadReport = false

    var body: some View {
        ZStack {
            VStack {
                Group {
                    if shouldLoadReport {
                        DeviceActivityReport(
                            .mujoToday,
                            filter: screenTime.reportFilter
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
    }
}

#Preview {
    ContentView()
}
