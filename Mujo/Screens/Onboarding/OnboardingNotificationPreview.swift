import Foundation
import SwiftUI

enum OnboardingNotificationStackPhase: Int, Equatable {
    case hidden
    case thirtyMinutes
    case fiveMinutes
    case expired

    static func initial(reduceMotionEnabled: Bool) -> Self {
        reduceMotionEnabled ? .expired : .hidden
    }

    var visibleNotificationCount: Int {
        rawValue
    }

    mutating func advance() {
        switch self {
        case .hidden:
            self = .thirtyMinutes
        case .thirtyMinutes:
            self = .fiveMinutes
        case .fiveMinutes, .expired:
            self = .expired
        }
    }
}

struct OnboardingNotificationStackLayout {
    let bannerHeight: CGFloat = 76

    private let depthOffset: CGFloat = 9
    private let depthScaleStep: CGFloat = 0.045

    func scale(atDepth depth: Int) -> CGFloat {
        1 - CGFloat(depth) * depthScaleStep
    }

    func verticalOffset(atDepth depth: Int) -> CGFloat {
        CGFloat(depth) * depthOffset
    }

    func exposedBottomEdge(atDepth depth: Int) -> CGFloat {
        guard depth > 0 else { return 0 }
        return bottomEdge(atDepth: depth) - bottomEdge(atDepth: depth - 1)
    }

    private func bottomEdge(atDepth depth: Int) -> CGFloat {
        bannerHeight * scale(atDepth: depth) + verticalOffset(atDepth: depth)
    }
}

private struct OnboardingNotificationPreviewContent: Identifiable {
    let id: Int
    let title: String
    let body: String

    static let sequence = [
        Self(
            id: 0,
            title: "30 min remaining",
            body: "Make the last minutes count."
        ),
        Self(
            id: 1,
            title: "5 min remaining",
            body: "Choose how you want to spend them."
        ),
        Self(
            id: 2,
            title: "Nothing remains.",
            body: "You've reached the time you chose for today."
        )
    ]
}

private struct OnboardingNotificationBanner: View {
    @Environment(\.colorScheme) private var colorScheme

    let content: OnboardingNotificationPreviewContent
    let height: CGFloat

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
                Text(content.title)
                    .font(.system(
                        size: OnboardingTypography.systemUI,
                        weight: .semibold
                    ))

                Text(content.body)
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
        .frame(height: height)
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
            color: Color.accentColor.opacity(0.08),
            radius: 10,
            y: 4
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

struct OnboardingNotificationStack: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotionEnabled
    @State private var phase = OnboardingNotificationStackPhase.hidden

    private let revealDelay = Duration.milliseconds(850)
    private let initialDelay = Duration.milliseconds(200)
    private let layout = OnboardingNotificationStackLayout()

    var body: some View {
        let visibleNotifications = OnboardingNotificationPreviewContent
            .sequence
            .prefix(phase.visibleNotificationCount)

        ZStack(alignment: .top) {
            ForEach(Array(visibleNotifications.enumerated()), id: \.element.id) {
                index, notification in
                let depth = visibleNotifications.count - index - 1

                OnboardingNotificationBanner(
                    content: notification,
                    height: layout.bannerHeight
                )
                    .scaleEffect(layout.scale(atDepth: depth), anchor: .top)
                    .offset(y: layout.verticalOffset(atDepth: depth))
                    .opacity(layerOpacity(depth: depth))
                    .zIndex(Double(visibleNotifications.count - depth))
                    .transition(
                        .move(edge: .top)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.96))
                    )
            }
        }
        .frame(height: layout.bannerHeight, alignment: .top)
        .accessibilityElement(children: .combine)
        .task {
            await playSequence()
        }
    }

    private func layerOpacity(depth: Int) -> Double {
        switch depth {
        case 0: 1
        case 1: 0.88
        default: 0.74
        }
    }

    @MainActor
    private func playSequence() async {
        guard phase == .hidden else { return }

        let initialPhase = OnboardingNotificationStackPhase.initial(
            reduceMotionEnabled: reduceMotionEnabled
        )
        guard initialPhase == .hidden else {
            phase = initialPhase
            return
        }

        do {
            try await Task.sleep(for: initialDelay)
            revealNextNotification()
            try await Task.sleep(for: revealDelay)
            revealNextNotification()
            try await Task.sleep(for: revealDelay)
            revealNextNotification()
        } catch {
            return
        }
    }

    @MainActor
    private func revealNextNotification() {
        withAnimation(.spring(duration: 0.46, bounce: 0.16)) {
            phase.advance()
        }
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

enum OnboardingLockScreenDateFormatter {
    static func display(
        for date: Date,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> (date: String, time: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = "EEE d"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.timeZone = timeZone
        timeFormatter.dateFormat = "HH:mm"

        return (
            date: dateFormatter.string(from: date),
            time: timeFormatter.string(from: date)
        )
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

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let display = OnboardingLockScreenDateFormatter.display(
                    for: context.date
                )

                VStack(spacing: 0) {
                    Text("\(display.date)  ·  \(remainingText)")
                        .font(.system(
                            size: 23,
                            weight: .semibold,
                            design: .rounded
                        ))
                        .foregroundStyle(clockColor)

                    Text(verbatim: display.time)
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
