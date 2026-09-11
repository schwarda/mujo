//
//  Background.swift
//  Mujo
//
//  Created by Lopk Art on 06/09/2026.
//
import SwiftUI

struct SakuraBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: MujoTheme.backgroundColors(for: colorScheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            RadialGradient(
                colors: [
                    MujoTheme.backgroundHighlight(for: colorScheme),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 210
            )
            .frame(width: 420, height: 420)
            .offset(x: 120, y: -130)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
