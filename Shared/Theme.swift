//
//  Theme.swift
//  Mujo
//

import SwiftUI

enum OnboardingTypography {
    static let descriptive: CGFloat = 18
    static let supporting: CGFloat = 16
    static let primaryAction: CGFloat = 17
    static let systemUI: CGFloat = 14
}

enum MujoTheme {
    static let secondaryTextOpacity = 0.72
    static let fontMedium = "AvenirNext-Medium"
    static let fontItalic = "AvenirNext-Italic"
    static let fontSemibold = "AvenirNext-DemiBold"
    static let fontSemiboldItalic = "AvenirNext-DemiBoldItalic"
    static let brandAccent = Color(
        red: 0.96,
        green: 0.62,
        blue: 0.72
    )
    static let glassAccent = brandAccent

    static func regularFont(
        size: CGFloat,
        relativeTo _: Font.TextStyle
    ) -> Font {
        .system(
            size: size,
            weight: .regular,
            design: .rounded
        )
    }

    static func mediumFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        .custom(
            fontMedium,
            size: size,
            relativeTo: textStyle
        )
    }

    static func italicFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        .custom(
            fontItalic,
            size: size,
            relativeTo: textStyle
        )
    }

    static func semiboldFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        .custom(
            fontSemibold,
            size: size,
            relativeTo: textStyle
        )
    }

    static func semiboldItalicFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        .custom(
            fontSemiboldItalic,
            size: size,
            relativeTo: textStyle
        )
    }

    static func boldFont(
        size: CGFloat,
        relativeTo _: Font.TextStyle
    ) -> Font {
        .system(
            size: size,
            weight: .bold,
            design: .rounded
        )
    }

    static func backgroundColors(for colorScheme: ColorScheme) -> [Color] {
        switch colorScheme {
        case .dark:
            [
                Color(red: 0.12, green: 0.07, blue: 0.11),
                Color(red: 0.24, green: 0.10, blue: 0.19)
            ]
        case .light:
            [
                Color(red: 1.00, green: 0.97, blue: 0.98),
                Color(red: 0.98, green: 0.90, blue: 0.95)
            ]
        @unknown default:
            [
                brandAccent.opacity(0.12),
                brandAccent.opacity(0.25)
            ]
        }
    }

    static func surfaceBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.07, blue: 0.11)
            : Color(red: 1.00, green: 0.97, blue: 0.98)
    }

    static func raisedSurfaceBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.24, green: 0.10, blue: 0.19)
            : Color(red: 0.98, green: 0.90, blue: 0.95)
    }

    static var lockScreenMockupBackgroundColors: [Color] {
        [
            brandAccent,
            Color(red: 1.000, green: 0.702, blue: 0.800)
        ]
    }

    static func widgetEmphasis(for colorScheme: ColorScheme) -> Color {
        surfaceBackground(for: colorScheme)
    }

    static func backgroundHighlight(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? brandAccent.opacity(0.16)
            : .white.opacity(0.72)
    }
}

struct OnboardingPrimaryButton<Label: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let action: () -> Void
    let isDisabled: Bool
    let label: () -> Label

    init(
        isDisabled: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.isDisabled = isDisabled
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
                .font(MujoTheme.mediumFont(
                    size: OnboardingTypography.primaryAction,
                    relativeTo: .body
                ))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .contentShape(Capsule())
                .foregroundStyle(
                    MujoTheme.surfaceBackground(for: colorScheme)
                )
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .tint(.accentColor)
        .disabled(isDisabled)
    }
}
