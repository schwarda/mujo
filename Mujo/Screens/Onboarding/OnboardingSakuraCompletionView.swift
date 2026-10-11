import SwiftUI

struct OnboardingSakuraCompletionView: View {
    var progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear

                AnimatedOnboardingSakuraVeil(progress: progress)

                ForEach(
                    OnboardingSakuraGust.petals(in: geometry.size),
                    id: \.index
                ) { petal in
                    AnimatedOnboardingSakuraPetal(
                        assetName: "petal_\((petal.index % 12) + 1)",
                        size: petal.size,
                        canvasWidth: geometry.size.width,
                        rotationMultiplier: petal.rotationMultiplier,
                        motion: petal.motion,
                        progress: progress
                    )
                }
            }
            .contentShape(Rectangle())
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct OnboardingSakuraWipeMask: View, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { geometry in
            let edgeX = OnboardingSakuraWipe.edgeX(
                at: progress,
                canvasWidth: geometry.size.width
            )
            let softEdgeWidth = OnboardingSakuraWipe.softEdgeWidth

            ZStack(alignment: .leading) {
                Color.white
                    .frame(width: max(0, edgeX - softEdgeWidth))

                LinearGradient(
                    colors: [.white, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: softEdgeWidth)
                .offset(x: edgeX - softEdgeWidth)
            }
        }
        .ignoresSafeArea()
    }
}

private struct AnimatedOnboardingSakuraVeil: View, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let distance = abs(progress - OnboardingSakuraGust.homeRevealProgress)
        let opacity = max(0, 1 - distance / 0.24) * 0.14

        Color(red: 1, green: 0.93, blue: 0.96)
            .opacity(opacity)
    }
}

private struct AnimatedOnboardingSakuraPetal: View, Animatable {
    let assetName: String
    let size: CGFloat
    let canvasWidth: CGFloat
    let rotationMultiplier: Double
    let motion: OnboardingSakuraPetalMotion
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let sample = motion.sample(
            at: progress,
            canvasWidth: canvasWidth,
            petalSize: size
        )

        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .rotationEffect(.degrees(
                sample.rotationDegrees * rotationMultiplier
            ))
            .opacity(sample.opacity)
            .position(sample.position)
    }
}

#if DEBUG
private struct OnboardingSakuraCompletionPreview: View {
    @State private var progress = 0.0

    var body: some View {
        ZStack {
            SakuraBackground()
            OnboardingSakuraCompletionView(progress: progress)
        }
        .task {
            await Task.yield()
            withAnimation(OnboardingSakuraGust.animation) {
                progress = 1
            }
        }
    }
}

private struct OnboardingSakuraTransitionPreview: View {
    @State private var progress = 0.0

    var body: some View {
        ZStack {
            HomeScreenPreview()

            ZStack {
                OnboardingBackground()
                OnboardingLimitSetupView(previewStep: .homeScreenWidget)
            }
            .mask {
                OnboardingSakuraWipeMask(progress: progress)
            }

            OnboardingSakuraCompletionView(progress: progress)
        }
        .task {
            await replayTransition()
        }
    }

    private func replayTransition() async {
        while !Task.isCancelled {
            progress = 0

            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }

            withAnimation(OnboardingSakuraGust.animation) {
                progress = 1
            }

            do {
                try await Task.sleep(
                    for: .seconds(
                        OnboardingSakuraGust.animationDuration + 1
                    )
                )
            } catch {
                return
            }
        }
    }
}

#Preview("Onboarding completion petals") {
    OnboardingSakuraCompletionPreview()
}

#Preview("Onboarding → Home · Sakura") {
    OnboardingSakuraTransitionPreview()
}
#endif
