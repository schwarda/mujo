//
//  HistoryScreen.swift
//  Mujo
//
//  Created by Lopk Art on 06/09/2026.
//

import SwiftUI

struct HistoryScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var screenTime: ScreenTimeManager
    @Binding var petalSimulationTime: Double
    @Binding var petalFlow: SakuraPetalFlowState
    let petalsStartFilled: Bool

    var body: some View {
        ZStack {
            SakuraPetalField(
                windStrength: 0,
                startsFilled: petalsStartFilled,
                simulationTime: $petalSimulationTime,
                emitsPetals: shouldEmitPetals,
                flowState: $petalFlow
            )

            VStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.tint)

                Text("Past days")
                    .font(.title2.weight(.semibold))
            }
        }
        .task {
            while !Task.isCancelled {
                if scenePhase == .active {
                    screenTime.refreshUsageSnapshot()
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var shouldEmitPetals: Bool {
        let estimate = screenTime.usageEstimate(
            forLimitMinutes: screenTime.dailyLimitMinutes
        )
        return !estimate.isAvailable || estimate.remainingTime > 0
    }
}

#Preview {
    HistoryScreen(
        screenTime: ScreenTimeManager(),
        petalSimulationTime: .constant(0),
        petalFlow: .constant(.initiallyEmitting),
        petalsStartFilled: true
    )
}
