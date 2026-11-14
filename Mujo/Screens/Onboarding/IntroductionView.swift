//
//  IntroductionView.swift
//  Mujo
//
//  Created by Aikari Studio on 08/09/2026.
//

import AVFoundation
import SwiftUI

struct IntroductionView: View {
    private nonisolated static let progressBarWidthRatio: CGFloat = 0.9

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    let isRequestingPermission: Bool
    @Binding var petalSimulationTime: Double
    let onCherryBlossomsStarted: () -> Void
    let onContinue: () -> Void

    @StateObject private var playback = OnboardingIntroductionVideoPlayback()
    @State private var didNotifyCherryBlossoms = false
    @State private var occlusionBottom: CGFloat?
    @State private var fittedVideoFrame: CGRect?

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
        if voiceOverEnabled {
            VoiceOverIntroductionView(
                isRequestingPermission: isRequestingPermission,
                onContinue: onContinue
            )
        } else {
            videoIntroduction
        }
    }

    private var videoIntroduction: some View {
        ZStack {
            videoWithAdaptiveEdges
                .onGeometryChange(for: CGFloat?.self) { layout in
                    Self.occlusionBottom(in: layout)
                } action: {
                    occlusionBottom = $0
                }
                .onGeometryChange(for: CGRect.self) { layout in
                    OnboardingIntroductionVideoPolicy.fittedVideoRect(
                        in: layout.frame(in: .global)
                    )
                } action: {
                    fittedVideoFrame = $0
                }
                .ignoresSafeArea()

            GeometryReader { layout in
                let layoutFrame = layout.frame(in: .global)
                let videoFrame = fittedVideoFrame ?? layoutFrame

                progressBar
                    .frame(width: videoFrame.width * Self.progressBarWidthRatio)
                    .frame(maxWidth: .infinity)
                    .offset(x: videoFrame.midX - layoutFrame.midX)
                    .padding(.top)
                    .padding(.top, progressBarOffset(in: layout))
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

    private var progressBar: some View {
        GeometryReader { geometry in
            Capsule()
                .fill(Color.accentColor.opacity(0.18))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * playback.progress)
                }
        }
        .frame(height: 4)
        .accessibilityLabel(
            "To know what remains, Mujø will need access to Screen Time."
        )
        .accessibilityValue("\(Int(playback.progress * 100)) percent")
    }

    private func progressBarOffset(in layout: GeometryProxy) -> CGFloat {
        guard let occlusionBottom else { return 0 }
        return max(0, occlusionBottom - layout.frame(in: .global).minY)
    }

    private nonisolated static func occlusionBottom(in layout: GeometryProxy) -> CGFloat? {
        guard #available(iOS 27.1, *) else { return nil }

        let videoFrame = OnboardingIntroductionVideoPolicy.fittedVideoRect(
            in: CGRect(origin: .zero, size: layout.size)
        )
        let halfBarWidth = videoFrame.width * progressBarWidthRatio / 2
        let barLeft = videoFrame.midX - halfBarWidth
        let barRight = videoFrame.midX + halfBarWidth

        let bottom = layout.reservedRegions(kind: .occlusion, options: .includeInactive)
            .map(\.frame)
            .filter { $0.maxX > barLeft && $0.minX < barRight }
            .map(\.maxY)
            .max()
        return bottom.map { layout.frame(in: .global).minY + $0 }
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

private struct VoiceOverIntroductionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @AccessibilityFocusState(for: .voiceOver) private var isNarrationFocused: Bool
    @StateObject private var playback = OnboardingIntroductionVideoPlayback()
    @State private var sceneIndex = 0
    @State private var replayCount = 0

    let isRequestingPermission: Bool
    let onContinue: () -> Void

    private var scenes: [OnboardingIntroductionVideoPolicy.VoiceOverScene] {
        OnboardingIntroductionVideoPolicy.voiceOverScenes
    }

    private var scene: OnboardingIntroductionVideoPolicy.VoiceOverScene {
        scenes[sceneIndex]
    }

    private var isLastScene: Bool { sceneIndex == scenes.count - 1 }

    var body: some View {
        let resourceName = OnboardingIntroductionVideoPolicy.resourceName(for: colorScheme)

        ScrollView {
            VStack(spacing: 18) {
                Text("Introduction to Mujø")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)

                OnboardingIntroductionVideo(
                    player: playback.player,
                    onTap: {},
                    onHoldModeChanged: { _ in }
                )
                .aspectRatio(OnboardingIntroductionVideoPolicy.videoSize, contentMode: .fit)
                .frame(height: 240)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Scene \(sceneIndex + 1) of \(scenes.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(scene.narration)
                        .multilineTextAlignment(.center)
                }
                .accessibilityElement(children: .combine)
                .accessibilityFocused($isNarrationFocused)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 20) { sceneControls }
                    VStack(spacing: 12) { sceneControls }
                }
                .buttonStyle(.bordered)
                .tint(.primary)
                .disabled(isRequestingPermission)
            }
            .frame(maxWidth: 420)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingPrimaryButton(
                isDisabled: isRequestingPermission,
                action: onContinue
            ) {
                if isRequestingPermission {
                    ProgressView("Requesting Screen Time access")
                        .labelStyle(.iconOnly)
                } else {
                    Text("Continue")
                }
            }
            .accessibilityHint("Continue to Screen Time access.")
            .padding(.horizontal, 34)
            .padding(.bottom, 24)
        }
        .task {
            await Task.yield()
            guard !Task.isCancelled else { return }
            isNarrationFocused = true
        }
        .task(id: PlaybackRequest(
            sceneIndex: sceneIndex,
            replayCount: replayCount,
            resourceName: resourceName,
            isActive: scenePhase == .active && !isRequestingPermission
        )) {
            if scenePhase == .active && !isRequestingPermission {
                await playback.playVoiceOverScene(scene, resourceName: resourceName)
            } else {
                playback.player.pause()
            }
        }
        .onDisappear { playback.stop() }
    }

    @ViewBuilder
    private var sceneControls: some View {
        Button("Previous scene") {
            sceneIndex -= 1
            announceScene()
        }
        .disabled(sceneIndex == 0)

        Button("Repeat scene") {
            replayCount += 1
            announceScene()
        }

        Button("Next scene") {
            sceneIndex += 1
            announceScene()
        }
        .disabled(isLastScene)
    }

    private func announceScene() {
        AccessibilityNotification.Announcement(String(localized: scene.narration)).post()
    }

    private struct PlaybackRequest: Equatable {
        let sceneIndex: Int
        let replayCount: Int
        let resourceName: String
        let isActive: Bool
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
