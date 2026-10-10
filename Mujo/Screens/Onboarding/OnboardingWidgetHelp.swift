import SwiftUI

enum OnboardingWidgetHelp: String, Identifiable {
    case lockScreen
    case homeScreen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lockScreen: "Add it to your\nLock Screen"
        case .homeScreen: "Add it to your\nHome Screen"
        }
    }

    var systemImage: String {
        switch self {
        case .lockScreen: "lock.rectangle.stack.fill"
        case .homeScreen: "rectangle.grid.2x2.fill"
        }
    }

    var steps: [Text] {
        switch self {
        case .lockScreen:
            [
                Text("Touch and hold your Lock Screen, then tap Customize."),
                Text("Choose Lock Screen and tap the widget area below/above the clock."),
                Text("Find Mujø in the widget list and tap the widget to add it.")
            ]
        case .homeScreen:
            [
                Text("Touch and hold an empty area of your Home Screen."),
                Text(
                    "Tap Edit \(Image(systemName: "paintbrush.fill")), then tap Add Widget."
                ),
                Text("Find Mujø, choose a widget, and tap Add Widget.")
            ]
        }
    }
}
struct OnboardingWidgetHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    let help: OnboardingWidgetHelp

    var body: some View {
        ZStack {
            SakuraBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Image(systemName: help.systemImage)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.tint)
                    .frame(width: 72, height: 72)
                    .background(
                        Color.accentColor.opacity(0.08),
                        in: RoundedRectangle(
                            cornerRadius: 22,
                            style: .continuous
                        )
                    )
                    .padding(.top, 42)

                Text(help.title)
                    .font(MujoTheme.boldFont(
                        size: 38,
                        relativeTo: .largeTitle
                    ))
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                VStack(spacing: 24) {
                    ForEach(Array(help.steps.enumerated()), id: \.offset) {
                        index, step in
                        HStack(alignment: .center, spacing: 16) {
                            Text("\(index + 1)")
                                .font(MujoTheme.boldFont(
                                    size: OnboardingTypography.descriptive,
                                    relativeTo: .body
                                ))
                                .foregroundStyle(.tint)
                                .frame(width: 38, height: 38)
                                .overlay {
                                    Circle()
                                        .stroke(
                                            Color.accentColor,
                                            lineWidth: 1.5
                                        )
                                }

                            step
                                .font(MujoTheme.italicFont(
                                    size: OnboardingTypography.descriptive,
                                    relativeTo: .body
                                ))
                                .foregroundStyle(.tint)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 42)

                Spacer(minLength: 24)

                OnboardingPrimaryButton(action: { dismiss() }) {
                    Text("Got it")
                }
                .padding(.horizontal, 34)
                .padding(.bottom, 24)
            }
        }
    }
}
