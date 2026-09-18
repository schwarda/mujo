//
//  IntroductionView.swift
//  Mujo
//
//  Created by Aikari Studio on 08/09/2026.
//
import SwiftUI

struct IntroductionView: View {
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
    private let maximumTextDuration = 5.0
    private let secondsPerWord = 0.24
    private let pausePerExtraLine = 0.18
    private let continueRevealDuration = 0.4

    let isRequestingPermission: Bool
    @Binding var petalSimulationTime: Double
    let onCherryBlossomsStarted: () -> Void
    let onContinue: () -> Void

    @State private var currentIndex = 0
    @State private var progressStartedAt: Date?
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

            VStack {
                TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
                    GeometryReader { geometry in
                        let progress = introductionProgress(at: timeline.date)

                        Capsule()
                            .fill(Color.accentColor.opacity(0.18))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(width: geometry.size.width * progress)
                            }
                    }
                    .frame(height: 4)
                    .accessibilityLabel("Introduction progress")
                    .accessibilityValue(
                        "\(Int(introductionProgress(at: timeline.date) * 100)) percent"
                    )
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
                }
                Spacer()
            }

            VStack(spacing: 28) {
                Spacer()

                Text(texts[currentIndex])
                    .id(currentIndex)
                    .font(MujoTheme.italicFont(
                        size: 22,
                        relativeTo: .title3
                    ))
                    .foregroundStyle(
                        .accent.opacity(MujoTheme.secondaryTextOpacity)
                    )
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
        guard !showsContinueButton else { return }
        if progressStartedAt == nil {
            progressStartedAt = .now
        }

        for index in currentIndex..<texts.count {
            let displayDuration = duration(for: texts[index])
            try? await Task.sleep(for: .seconds(displayDuration))
            guard !Task.isCancelled else { return }

            if index + 1 < texts.count {
                withAnimation(.easeInOut(duration: 0.45)) {
                    currentIndex = index + 1
                }

                if index + 1 == cherryBlossomIndex {
                    onCherryBlossomsStarted()
                }
            }
        }

        withAnimation(.easeOut(duration: continueRevealDuration)) {
            showsContinueButton = true
        }
    }

    private func introductionProgress(at date: Date) -> CGFloat {
        guard let progressStartedAt else { return 0 }
        let totalDuration = texts.reduce(0.0) {
            $0 + duration(for: $1)
        } + continueRevealDuration
        guard totalDuration > 0 else { return 1 }
        return CGFloat(min(1, max(0,
            date.timeIntervalSince(progressStartedAt) / totalDuration
        )))
    }

    private func duration(for text: String) -> TimeInterval {
        let wordCount = text.split { $0.isWhitespace }.count
        let extraLineCount = max(0, text.components(separatedBy: "\n").count - 1)
        let readingTime = 1.0
            + Double(wordCount) * secondsPerWord
            + Double(extraLineCount) * pausePerExtraLine
        let clampedTime = min(
            maximumTextDuration,
            max(minimumTextDuration, readingTime)
        )

        return clampedTime
    }
}

#Preview {
    IntroductionView()
}
