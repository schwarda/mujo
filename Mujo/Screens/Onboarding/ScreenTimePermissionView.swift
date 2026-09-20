//
//  ScreenTimePermissionView.swift
//  Mujo
//

import SwiftUI

struct ScreenTimePermissionView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "hourglass")
                .font(.system(size: 46, weight: .medium))
                .foregroundStyle(.tint)

            Text("To know what remains")
                .font(.system(
                    .title3,
                    design: .rounded,
                    weight: .semibold
                ))

            Text(
                "Mujø needs access to your Screen Time. It won't be able "
                    + "to see what you're doing on the screen. It will only "
                    + "use your Screen Time to keep track of what remains."
            )
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button("Allow Access", action: retry)
                .font(.system(.body, design: .rounded))
                .buttonStyle(.glass)
        }
        .padding(32)
    }
}

#Preview {
    ScreenTimePermissionView(
        retry: {}
    )
}
