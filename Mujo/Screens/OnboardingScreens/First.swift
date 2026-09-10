//
//  FirstScreen.swift
//  Mujo
//
//  Created by Aikari Studio on 08/09/2026.
//
import SwiftUI

struct FirstScreen: View {
    private let texts: [String] = [
        "Nothing remains",
        "Time passes",
        "Your time is finite.\nWhat you give your attention to\nis your choice",
        "Your screen takes some of it",
        "But not all screen time is wasted time",
        "What matters is choosing\nhow much of today\nyou're willing to give to it",
        "Mujø is inspired by\nthe Japanese idea of Mono no aware",
        "an awareness that\nnothing lasts forever",
        "Cherry blossoms remind us of this",
        "Their beauty lies, in part,\nin knowing they will soon fall",
        "So does time",
        "Mujø won't tell you\nhow to spend yours",
        "You choose",
        "Mujø simply reminds you\nwhat remains",
        "And to do that...",
        "Mujø needs access to Screen Time\nto know how much of your time remains",
        "It doesn't see what you do on your screen",
        "It only keeps track of the time"
    ]

    private let cherryBlossomIndex = 8
    private let minimumTextDuration = 2.1
    private let maximumTextDuration = 5.8
    private let secondsPerWord = 0.38
    private let pausePerExtraLine = 0.45

    let isRequestingPermission: Bool
    @Binding var petalSimulationTime: Double
    let onCherryBlossomsStarted: () -> Void
    let onContinue: () -> Void

    @State private var currentIndex = 0
    @State private var showsContinueButton = false

    init(
        isRequestingPermission: Bool = false,
        petalSimulationTime: Binding<Double> = .constant(0),
        onCherryBlossomsStarted: @escaping () -> Void = {},
        onContinue: @escaping () -> Void = {}
    ) {
        self.isRequestingPermission = isRequestingPermission
        _petalSimulationTime = petalSimulationTime
        self.onCherryBlossomsStarted = onCherryBlossomsStarted
        self.onContinue = onContinue
    }

    var body: some View {
        ZStack {
            if currentIndex >= cherryBlossomIndex {
                SakuraPetalField(
                    windStrength: 0,
                    startsFilled: false,
                    simulationTime: $petalSimulationTime
                )
            }

            VStack(spacing: 28) {
                Spacer()

                Text(texts[currentIndex])
                    .id(currentIndex)
                    .font(.custom(
                        "AvenirNext-Italic",
                        size: 22,
                        relativeTo: .title3
                    ))
                    .foregroundStyle(.accent.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.97))
                    )

                if showsContinueButton {
                    Button("Continue", action: onContinue)
                        .buttonStyle(.glass)
                        .disabled(isRequestingPermission)
                        .overlay {
                            if isRequestingPermission {
                                ProgressView()
                            }
                        }
                        .transition(
                            .move(edge: .bottom).combined(with: .opacity)
                        )
                }

                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .task {
            await playIntroduction()
        }
    }

    private func playIntroduction() async {
        guard currentIndex == 0, !showsContinueButton else { return }

        for nextIndex in texts.indices.dropFirst() {
            try? await Task.sleep(for: duration(for: texts[currentIndex]))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.8)) {
                currentIndex = nextIndex
            }

            if nextIndex == cherryBlossomIndex {
                onCherryBlossomsStarted()
            }
        }

        // The final sentence remains alone for its full reading time before
        // the action appears beneath it.
        try? await Task.sleep(for: duration(for: texts[currentIndex]))
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 0.4)) {
            showsContinueButton = true
        }
    }

    private func duration(for text: String) -> Duration {
        let wordCount = text.split { $0.isWhitespace }.count
        let extraLineCount = max(0, text.components(separatedBy: "\n").count - 1)
        let readingTime = 1.0
            + Double(wordCount) * secondsPerWord
            + Double(extraLineCount) * pausePerExtraLine
        let clampedTime = min(
            maximumTextDuration,
            max(minimumTextDuration, readingTime)
        )

        return .seconds(clampedTime)
    }
}

#Preview {
    FirstScreen()
}
