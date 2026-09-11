//
//  Theme.swift
//  Mujo
//

import SwiftUI

enum MujoTheme {
    static let secondaryTextOpacity = 0.72
    static let glassAccent = Color(
        red: 0.96,
        green: 0.62,
        blue: 0.72
    )

    static func mediumFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        .custom(
            "AvenirNext-Medium",
            size: size,
            relativeTo: textStyle
        )
    }

    static func italicFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        .custom(
            "AvenirNext-Italic",
            size: size,
            relativeTo: textStyle
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
            [.pink.opacity(0.12), .pink.opacity(0.25)]
        }
    }

    static func backgroundHighlight(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? .pink.opacity(0.16)
            : .white.opacity(0.72)
    }
}
