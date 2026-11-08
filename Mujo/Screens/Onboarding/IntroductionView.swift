//
//  IntroductionView.swift
//  Mujo
//
//  Created by Aikari Studio on 08/09/2026.
//

import SwiftUI

struct IntroductionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    let isRequestingPermission: Bool
    @Binding var petalSimulationTime: Double
    let onCherryBlossomsStarted: () -> Void
    let onContinue: () -> Void

    @StateObject private var playback = OnboardingIntroductionVideoPlayback()
    @State private var didNotifyCherryBlossoms = false

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
            videoWithAdaptiveEdges
                .ignoresSafeArea()

            VStack {
                GeometryReader { geometry in
                    Capsule()
                        .fill(Color.accentColor.opacity(0.18))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(
                                    width: geometry.size.width
                                        * playback.progress
                                )
                        }
                }
                .frame(height: 4)
                .accessibilityLabel(
                    "To know what remains, Mujø will need access to Screen Time."
                )
                .accessibilityValue(
                    "\(Int(playback.progress * 100)) percent"
                )
                .padding(.horizontal, 28)
                .padding(.top, 16)

                Spacer()
            }

            if playback.isFinished {
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
        .animation(.easeOut(duration: 0.4), value: playback.isFinished)
        .task {
            playback.start(resourceName: videoResourceName)
            playback.setActive(scenePhase == .active)
        }
        .onChange(of: colorScheme) { _, _ in
            playback.updateResource(videoResourceName)
        }
        .onChange(of: scenePhase) { _, newPhase in
            playback.setActive(newPhase == .active)
        }
        .onChange(of: playback.elapsedTime) { _, elapsedTime in
            petalSimulationTime = elapsedTime
        }
        .onChange(of: playback.progress) { _, progress in
            guard !didNotifyCherryBlossoms,
                progress >= OnboardingIntroductionVideoPolicy
                    .cherryBlossomProgress else {
                return
            }
            didNotifyCherryBlossoms = true
            onCherryBlossomsStarted()
        }
        .onDisappear {
            playback.stop()
        }
    }

    private var videoResourceName: String {
        OnboardingIntroductionVideoPolicy.resourceName(for: colorScheme)
    }

    private var videoWithAdaptiveEdges: some View {
        GeometryReader { geometry in
            let bounds = CGRect(origin: .zero, size: geometry.size)
            let videoRect = OnboardingIntroductionVideoPolicy.fittedVideoRect(in: bounds)
            let background = OnboardingIntroductionVideoPolicy.backgroundColor(
                at: playback.elapsedTime,
                colorScheme: colorScheme
            )
            let hasMargin = videoRect.width < bounds.width - 1
                || videoRect.height < bounds.height - 1

            ZStack {
                background

                OnboardingIntroductionVideo(
                    player: playback.player,
                    onTap: {
                        Task { await playback.skipToNextText() }
                    },
                    onHoldModeChanged: { holdMode in
                        playback.setHoldMode(holdMode)
                    }
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .accessibilityLabel("Introduction video")
                .accessibilityHint(
                    "Tap for the next message. Hold either edge for double speed, or hold the middle to pause."
                )
                .accessibilityAction(named: "Next message") {
                    Task { await playback.skipToNextText() }
                }

                if hasMargin {
                    videoEdgeFade(in: videoRect, background: background)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func videoEdgeFade(in rect: CGRect, background: Color) -> some View {
        let fade = min(rect.width, rect.height) * 0.08
        return ZStack {
            LinearGradient(
                colors: [background, background.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: fade, height: rect.height)
            .position(x: rect.minX + fade / 2, y: rect.midY)

            LinearGradient(
                colors: [background.opacity(0), background],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: fade, height: rect.height)
            .position(x: rect.maxX - fade / 2, y: rect.midY)

            LinearGradient(
                colors: [background, background.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: rect.width, height: fade)
            .position(x: rect.midX, y: rect.minY + fade / 2)

            LinearGradient(
                colors: [background.opacity(0), background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: rect.width, height: fade)
            .position(x: rect.midX, y: rect.maxY - fade / 2)
        }
    }
}

#if DEBUG
#Preview("Introduction video · Light") {
    IntroductionView()
        .preferredColorScheme(.light)
}

#Preview("Introduction video · Dark") {
    IntroductionView()
        .preferredColorScheme(.dark)
}
#endif
