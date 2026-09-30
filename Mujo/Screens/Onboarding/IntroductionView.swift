//
//  IntroductionView.swift
//  Mujo
//
//  Created by Aikari Studio on 08/09/2026.
//
import SwiftUI

struct IntroductionView: View {
    private let texts: [String] = [
        "Time passes.\nAnd what passes\ndoesn't return.",
        "Your time is finite.",
        "In Japan, cherry blossoms\nare cherished for their fleeting beauty.",
        "They bloom.\nThey fall.\nThey pass.",
        "Their beauty lies, in part,\nin knowing they won't last.",
        "This feeling has a name:\nmono no aware.",
        "Our time is much the same.",
        "Where your attention goes,\nyour time follows.",
        "And every day,\nsome of it goes to a screen.",
        "That's not necessarily time wasted.",
        "What matters is choosing\nhow much of today\nyou're willing to give to it.",
        "Mujø will simply keep you aware\nof what remains.",
        "To do that, Mujø needs\naccess to Screen Time.",
        "It won't see what you do.\nOnly the time you spend."
    ]

    private let cherryBlossomIndex = 2
    private let minimumTextDuration = 2.1
    private let maximumTextDuration = 5.8
    private let secondsPerWord = 0.27
    private let pausePerExtraLine = 0.24
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

            VStack {
                Spacer()

                introductionText
                    .id(currentIndex)
                    .font(MujoTheme.italicFont(
                        size: 22,
                        relativeTo: .title3
                    ))
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.97))
                    )

                Spacer()
            }
            .padding(.horizontal, 28)

            if showsContinueButton {
                VStack {
                    Spacer()

                    OnboardingPrimaryButton(
                        isDisabled: isRequestingPermission,
                        action: onContinue
                    ) {
                        if isRequestingPermission {
                            ProgressView()
                        } else {
                            Text("Continue")
                        }
                    }
                    .transition(
                        .move(edge: .bottom).combined(with: .opacity)
                    )
                }
                .padding(.horizontal, 34)
                .padding(.bottom, 34)
            }
        }
        .task {
            await playIntroduction()
        }
    }

    @ViewBuilder
    private var introductionText: some View {
        if currentIndex == 5 {
            let name = Text("mono no aware")
                .font(MujoTheme.semiboldFont(
                    size: 22,
                    relativeTo: .title3
                ))
            Text("This feeling has a name:\n\(name).")
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
