//
//  ScreenTimePermissionView.swift
//  Mujo
//

import SwiftUI

struct ScreenTimePermissionView: View {
    @Binding var petalSimulationTime: Double
    let petalsStartFilled: Bool
    let retry: () -> Void

    var body: some View {
        ZStack {
            SakuraPetalField(
                windStrength: 0,
                startsFilled: petalsStartFilled,
                simulationTime: $petalSimulationTime
            )

            VStack(spacing: 18) {
                Image(systemName: "hourglass")
                    .font(.system(size: 46, weight: .medium))
                    .foregroundStyle(.tint)

                Text("Screen Time access is required")
                    .font(.title3.weight(.semibold))

                Text(
                    "Mujø needs permission to calculate how much time "
                        + "remains today."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                Button("Allow Access", action: retry)
                    .buttonStyle(.glass)
            }
            .padding(32)
        }
    }
}

#Preview {
    ScreenTimePermissionView(
        petalSimulationTime: .constant(0),
        petalsStartFilled: true,
        retry: {}
    )
}
