//
//  GlassText.swift
//  Mujo
//
//  Created by Aikari Studio on 09/09/2026.
//

import SwiftUI

struct GlassText: View {
    var value: String
    var size: CGFloat = 118

    private var timeFont: Font {
        .system(
            size: size,
            weight: .heavy,
            design: .rounded
        )
    }

    private func timeText(_ value: String) -> some View {
        Text(value)
            .font(timeFont)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    var body: some View {
        ZStack {
            timeText(value)
                .foregroundStyle(MujoTheme.glassAccent.opacity(0.68))

            timeText(value)
                .foregroundStyle(.white.opacity(0.24))
                .offset(x: -0.7, y: -0.9)
                .blendMode(.screen)
        }
        .compositingGroup()
        .shadow(
            color: .white.opacity(0.32),
            radius: 1,
            x: -1,
            y: -1
        )
        .shadow(
            color: MujoTheme.glassAccent.opacity(0.30),
            radius: 3,
            x: 1,
            y: 2
        )
    }
}
