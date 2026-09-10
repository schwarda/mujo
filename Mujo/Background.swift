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
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            RadialGradient(
                colors: [highlightColor, .clear],
                center: .center,
                startRadius: 0,
                endRadius: 210
            )
            .frame(width: 420, height: 420)
            .offset(x: 120, y: -130)
        }
        .ignoresSafeArea()
    }

    private var backgroundColors: [Color] {
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

    private var highlightColor: Color {
        colorScheme == .dark
            ? .pink.opacity(0.16)
            : .white.opacity(0.72)
    }
}

#Preview {
    ContentView()
}
