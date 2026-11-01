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
            OnboardingIntroductionVideo(
                player: playback.player,
                onTap: {
                    Task { await playback.skipToNextText() }
                },
                onHoldModeChanged: { holdMode in
                    playback.setHoldMode(holdMode)
                }
            )
                .ignoresSafeArea()
                .accessibilityLabel("Introduction video")
                .accessibilityHint(
                    "Tap for the next message. Hold either edge for double speed, or hold the middle to pause."
                )
                .accessibilityAction(named: "Next message") {
                    Task { await playback.skipToNextText() }
                }

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
