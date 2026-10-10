import SwiftUI

struct OnboardingNotificationBanner: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(appIconBackground)
                    .frame(width: 40, height: 40)

                Image(OnboardingAssetName.launchLogo)
                    .resizable()
                    .scaledToFit()
                    .padding(1)
            }
            .frame(width: 48, height: 48)
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("Nothing remains.")
                    .font(.system(
                        size: OnboardingTypography.systemUI,
                        weight: .semibold
                    ))

                Text("You've reached the time you chose for today.")
                    .font(.system(
                        size: OnboardingTypography.systemUI,
                        weight: .regular
                    ))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(notificationTextColor)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(notificationBackground, in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(notificationBorder, lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            Text("now")
                .font(.system(
                    size: 12,
                    weight: .regular
                ))
                .foregroundStyle(notificationTimestampColor)
                .padding(.top, 10)
                .padding(.trailing, 16)
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.16),
            radius: 16,
            y: 8
        )
        .shadow(
            color: Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.16),
            radius: 20,
            y: 8
        )
        .accessibilityElement(children: .combine)
    }

    private var notificationTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var notificationTimestampColor: Color {
        notificationTextColor.opacity(0.56)
    }

    private var notificationBackground: Color {
        MujoTheme.surfaceBackground(for: colorScheme)
    }

    private var notificationBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.16)
            : Color.white.opacity(0.90)
    }

    private var appIconBackground: Color {
        MujoTheme.raisedSurfaceBackground(for: colorScheme)
    }
}
struct NotificationRequestErrorOverlay: View {
    let tryAgain: () -> Void
    let continueWithoutNotifications: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Notifications couldn’t be enabled.")
                    .font(MujoTheme.boldFont(
                        size: 24,
                        relativeTo: .title2
                    ))

                Text("Please try again.")
                    .font(MujoTheme.mediumFont(size: 17, relativeTo: .body))
                    .padding(.top, 8)

                OnboardingPrimaryButton(action: tryAgain) {
                    Text("Try again")
                }
                .padding(.top, 28)

                OnboardingSecondaryButton(
                    title: "Continue without notifications",
                    action: continueWithoutNotifications
                )
                .padding(.top, 5)
            }
            .foregroundStyle(.tint)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .padding(.horizontal, 26)
        }
        .transition(.opacity)
        .zIndex(10)
    }
}

struct OnboardingLockScreenMockup: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let remainingText = Text(verbatim: "1:30 remaining")
            .foregroundStyle(widgetEmphasisColor)

        ZStack(alignment: .top) {
            LinearGradient(
                colors: mockupGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                Text("Sat 26  ·  \(remainingText)")
                    .font(.system(
                        size: 23,
                        weight: .semibold,
                        design: .rounded
                    ))
                    .foregroundStyle(clockColor)

                Text("17:11")
                    .font(.system(
                        size: 114,
                        weight: .bold,
                        design: .rounded
                    ))
                    .foregroundStyle(clockColor)
                    .tracking(-2)
                    .padding(.top, -4)

                ZStack {
                    Circle()
                        .stroke(
                            supportingContentColor.opacity(0.35),
                            lineWidth: 2.5
                        )

                    Circle()
                        .trim(from: 0, to: 0.5)
                        .stroke(
                            widgetEmphasisColor,
                            style: StrokeStyle(
                                lineWidth: 2.5,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))

                    Text("1:30")
                        .font(.system(
                            size: 15,
                            weight: .semibold,
                            design: .rounded
                        ))
                        .foregroundStyle(widgetEmphasisColor)
                }
                .frame(width: 58, height: 58)
                .padding(.top, -8)
            }
            .padding(.top, 78)
        }
        .clipShape(
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    bottomLeading: 60,
                    bottomTrailing: 60
                ),
                style: .continuous
            )
        )
        .shadow(
            color: mockupPink.opacity(0.48),
            radius: 22,
            y: 14
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Lock Screen preview showing one hour and thirty minutes remaining"
        )
    }

    private var clockColor: Color {
        mockupForegroundColor.opacity(0.70)
    }

    private var supportingContentColor: Color {
        mockupForegroundColor.opacity(0.60)
    }

    private var widgetEmphasisColor: Color {
        MujoTheme.widgetEmphasis(for: colorScheme)
    }

    private var mockupPink: Color {
        MujoTheme.brandAccent
    }

    private var mockupForegroundColor: Color {
        MujoTheme.surfaceBackground(for: colorScheme)
    }

    private var mockupGradientColors: [Color] {
        MujoTheme.lockScreenMockupBackgroundColors
    }

}

struct OnboardingSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(MujoTheme.mediumFont(
                size: OnboardingTypography.supporting,
                relativeTo: .body
            ))
            .foregroundStyle(.tint)
            .buttonStyle(.plain)
            .frame(minHeight: 44)
    }
}

struct OnboardingLimitReachedMark: View {
    var body: some View {
        Image(OnboardingAssetName.launchLogo)
            .resizable()
            .scaledToFit()
            .frame(width: 220, height: 220)
            .shadow(
                color: Color.accentColor.opacity(0.24),
                radius: 18,
                y: 10
            )
            .accessibilityLabel("Mujø")
    }
}
