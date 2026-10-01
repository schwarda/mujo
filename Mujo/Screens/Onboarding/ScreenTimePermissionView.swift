//
//  ScreenTimePermissionView.swift
//  Mujo
//

import SwiftUI

struct ScreenTimePermissionView: View {
    let isRequestingAccess: Bool
    let retry: () -> Void

    var body: some View {
        ZStack {
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
                    .foregroundStyle(.tint)

                Text(
                    "Mujø needs access to your Screen Time. It won't be able "
                        + "to see what you're doing on the screen. It will only "
                        + "use your Screen Time to keep track of what remains."
                )
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.tint)
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            VStack {
                Spacer()

                OnboardingPrimaryButton(
                    isDisabled: isRequestingAccess,
                    action: retry
                ) {
                    if isRequestingAccess {
                        ProgressView()
                    } else {
                        Text("Allow Access")
                    }
                }
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 34)
        }
    }
}
