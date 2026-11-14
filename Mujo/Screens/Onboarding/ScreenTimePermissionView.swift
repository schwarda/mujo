//
//  ScreenTimePermissionView.swift
//  Mujo
//

import SwiftUI

struct ScreenTimePermissionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .subheadline) private var iconSize = 34.0

    let isRequestingAccess: Bool
    let retry: () -> Void

    var body: some View {
        ViewThatFits(in: .vertical) {
            explanation
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                explanation
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
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
            .padding(.horizontal, 34)
            .padding(.bottom, 34)
        }
    }

    private var explanation: some View {
        VStack(spacing: 24) {
            VStack(spacing: 18) {
                Image(systemName: "hourglass")
                    .font(.system(size: 46, weight: .medium))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text("To know what remains")
                    .font(.system(
                        .title2,
                        design: .rounded,
                        weight: .semibold
                    ))
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
            }

            VStack(alignment: .leading, spacing: 16) {
                privacyRow(
                    "Mujø doesn’t send your Screen Time data off this device.",
                    icon: "lock"
                )
                privacyRow(
                    "Mujø doesn’t keep a copy of your Screen Time history.",
                    icon: "externaldrive"
                )
                privacyRow(
                    "Mujø can’t see what you do on your screen.",
                    icon: "eye.slash"
                )
                privacyRow(
                    "Mujø uses it only to show your usage and calculate your remaining time.",
                    icon: "clock"
                )
            }
            .frame(maxWidth: 360)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
    }

    private func privacyRow(
        _ message: LocalizedStringKey,
        icon: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: iconSize, height: iconSize)
                .background(
                    MujoTheme.raisedSurfaceBackground(for: colorScheme),
                    in: .circle
                )
                .accessibilityHidden(true)

            Text(message)
                .font(MujoTheme.italicFont(
                    size: OnboardingTypography.supporting,
                    relativeTo: .subheadline
                ))
                .multilineTextAlignment(.leading)
        }
    }
}

#if DEBUG
private struct ScreenTimePermissionPreview: View {
    var body: some View {
        ZStack {
            OnboardingBackground()
            ScreenTimePermissionView(isRequestingAccess: false, retry: {})
        }
    }
}

#Preview("Screen Time Permission · Light") {
    ScreenTimePermissionPreview()
        .preferredColorScheme(.light)
}

#Preview("Screen Time Permission · Dark") {
    ScreenTimePermissionPreview()
        .preferredColorScheme(.dark)
}
#endif
