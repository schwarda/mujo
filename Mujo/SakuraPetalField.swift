//
//  SakuraPetalField.swift
//  Mujo
//

import SwiftUI

struct SakuraPetalField: View {
    private struct Configuration {
        let petalCount = 22
        let baseSpeed = 1.0
        let maximumWindBoost = 4.5
        let framesPerSecond = 60.0
        let minimumPetalSize = 18.0
        let maximumPetalSize = 32.0
        let initialArrivalSpread = 5.0
    }

    private struct Petal: Identifiable {
        let id: Int
        let assetName: String
        let phase: Double
        let startingHeight: Double
        let fallingDistance: Double
        let cycleDuration: Double
        let sizeFactor: Double
        let swayPhase: Double
        let swayAmount: Double
        let rotations: Double
    }

    private final class SimulationClock {
        private(set) var time: TimeInterval
        private var previousFrameDate: Date?

        init(time: TimeInterval) {
            self.time = time
        }

        func advance(
            to date: Date,
            speed: Double,
            isPaused: Bool
        ) -> TimeInterval {
            defer { previousFrameDate = date }

            guard !isPaused else { return 0 }
            guard let previousFrameDate else { return time }

            let frameDuration = min(
                0.1,
                max(0, date.timeIntervalSince(previousFrameDate))
            )
            time += frameDuration * speed
            return time
        }
    }

    let windStrength: Double
    let startsFilled: Bool
    @Binding private var simulationTime: Double

    private let configuration = Configuration()
    private let petals: [Petal]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock: SimulationClock

    init(
        windStrength: Double,
        startsFilled: Bool = true,
        simulationTime: Binding<Double>
    ) {
        self.windStrength = windStrength
        self.startsFilled = startsFilled
        _simulationTime = simulationTime
        _clock = State(
            initialValue: SimulationClock(time: simulationTime.wrappedValue)
        )

        let configuration = Configuration()
        petals = (0..<configuration.petalCount).map { index in
            Petal(
                id: index,
                assetName: "petal_\((index % 12) + 1)",
                phase: Self.random(index, salt: 1),
                startingHeight: Self.random(index, salt: 2),
                fallingDistance: Self.random(index, salt: 3),
                cycleDuration: 11 + Self.random(index, salt: 4) * 9,
                sizeFactor: Self.random(index, salt: 5),
                swayPhase: Self.random(index, salt: 6) * .pi * 2,
                swayAmount: 10 + Self.random(index, salt: 7) * 24,
                rotations: 0.7 + Self.random(index, salt: 8) * 1.8
            )
        }
    }

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1 / configuration.framesPerSecond,
                paused: reduceMotion
            )
        ) { timeline in
            let speed = configuration.baseSpeed
                + max(0, min(1, windStrength))
                * configuration.maximumWindBoost
            let currentTime = clock.advance(
                to: timeline.date,
                speed: speed,
                isPaused: reduceMotion
            )

            GeometryReader { proxy in
                ZStack {
                    ForEach(petals) { petal in
                        petalView(
                            petal,
                            canvasSize: proxy.size,
                            time: currentTime
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onDisappear {
            simulationTime = clock.time
        }
    }

    private func petalView(
        _ petal: Petal,
        canvasSize: CGSize,
        time: TimeInterval
    ) -> some View {
        let entryDelay = startsFilled
            ? 0
            : petal.phase * configuration.initialArrivalSpread
        let rawProgress = startsFilled
            ? time / petal.cycleDuration + petal.phase
            : (time - entryDelay) / petal.cycleDuration
        let hasEntered = rawProgress >= 0
        let progress = hasEntered
            ? rawProgress - floor(rawProgress)
            : 0
        let petalSize = configuration.minimumPetalSize
            + (configuration.maximumPetalSize - configuration.minimumPetalSize)
            * petal.sizeFactor

        let horizontalDistance = canvasSize.width + petalSize * 2
        let x = canvasSize.width + petalSize
            - progress * horizontalDistance

        let startingAreaHeight = startsFilled
            ? canvasSize.height * 0.62
            : canvasSize.height * 0.50
        let startY = -petalSize
            + petal.startingHeight * startingAreaHeight
        let fall = canvasSize.height
            * (0.28 + petal.fallingDistance * 0.30)
        let sway = sin(progress * .pi * 4 + petal.swayPhase)
            * petal.swayAmount
        let y = startY + progress * fall + sway

        let edgeFade = min(
            1,
            min(progress / 0.08, (1 - progress) / 0.08)
        )

        return Image(petal.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: petalSize, height: petalSize)
            .rotationEffect(
                .degrees(
                    progress * 360 * petal.rotations
                        + petal.swayPhase * 30
                )
            )
            .opacity(hasEntered ? edgeFade * 0.82 : 0)
            .position(x: x, y: y)
    }

    private static func random(_ index: Int, salt: Int) -> Double {
        let value = sin(Double(index * 97 + salt * 53)) * 43_758.5453
        return value - floor(value)
    }
}

#Preview {
    ContentView()
}
