//
//  HistoryScreen.swift
//  Mujo
//
//  Created by Lopk Art on 06/09/2026.
//

import SwiftUI

struct HistoryScreen: View {
    @Binding var petalSimulationTime: Double
    let petalsStartFilled: Bool

    var body: some View {
        ZStack {
            SakuraPetalField(
                windStrength: 0,
                startsFilled: petalsStartFilled,
                simulationTime: $petalSimulationTime
            )

            VStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.tint)

                Text("Past days")
                    .font(.title2.weight(.semibold))
            }
        }
    }
}

#Preview {
    HistoryScreen(
        petalSimulationTime: .constant(0),
        petalsStartFilled: true
    )
}
