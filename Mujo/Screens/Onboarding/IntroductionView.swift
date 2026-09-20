//
//  IntroductionView.swift
//  Mujo
//
//  Created by Aikari Studio on 08/09/2026.
//
import SwiftUI

struct IntroductionView: View {
    private let texts: [String] = [
        "Time passes.",
        "And what passes\ndoesn't return.",
        "Your time is finite.",
        "In Japan, cherry blossoms\nare cherished for their fleeting beauty.",
        "They bloom.",
        "They fall.",
        "They pass.",
        "an awareness that\nnothing lasts forever",
        "Their beauty lies, in part,\nin knowing they won't last.",
        "This awareness of impermanence is called\nmono no aware.",
        "Our time is much the same.",
        "Where your time goes\nis shaped by your attention.",
        "And every day,\nsome of it goes to a screen.",
        "That's not necessarily time wasted.",
        "What matters is choosing\nhow much of today\nyou're willing to give to it.",
        "Mujø won't decide for you.",
        "You choose.",
        "Mujø simply keeps you aware\nof what remains.",
        "The choice of what remains is up to you."
    ]

    private let cherryBlossomIndex = 3
    private let minimumTextDuration = 2.1
    private let maximumTextDuration = 5.0
    private let secondsPerWord = 0.24
    private let pausePerExtraLine = 0.18
    private let continueRevealDuration = 0.4
    private let cherryBlossomEmissionDuration = 5.0

    let isRequestingPermission: Bool
    @Binding var petalSimulationTime: Double
    let onCherryBlossomsStarted: () -> Void
    let onContinue: () -> Void

    @State private var currentIndex = 0
    @State private var progressStartedAt: Date?
    @State private var showsContinueButton = false
    @State private var emitsCherryBlossoms = true
    @State private var petalFlow = SakuraPetalFlowState()

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
                    simulationTime: $petalSimulationTime,
                    emitsPetals: emitsCherryBlossoms,
                    flowState: $petalFlow
                )
                .task {
                    try? await Task.sleep(
                        for: .seconds(cherryBlossomEmissionDuration)
                    )
                    guard !Task.isCancelled else { return }
                    emitsCherryBlossoms = false
                }
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
                    .accessibilityLabel(
                        "To know what remains, Mujø will need access to Screen Time."
                    )
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

                introductionText
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
                        .font(.system(.body, design: .rounded))
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

    @ViewBuilder
    private var introductionText: some View {
        if currentIndex == 9 {
            let name = Text("mono no aware.")
                .font(MujoTheme.semiboldFont(
                    size: 22,
                    relativeTo: .title3
                ))
            Text("This awareness of impermanence is called\n\(name)")
        } else {
            Text(texts[currentIndex])
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
