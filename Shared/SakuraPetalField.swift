//
//  SakuraPetalField.swift
//  Mujo
//

import SwiftUI

struct SakuraPetalFlowState {
    struct Stream: Identifiable {
        let id: Int
        let startTime: TimeInterval?
        var stopTime: TimeInterval?
    }

    static let initiallyEmitting = Self(
        isEmitting: true,
        streams: [Stream(id: 0, startTime: nil, stopTime: nil)],
        nextStreamID: 1
    )

    private(set) var isEmitting: Bool?
    private(set) var streams: [Stream] = []
    private var nextStreamID = 0

    mutating func reconcile(emitsPetals: Bool, at time: TimeInterval) {
        guard let wasEmitting = isEmitting else {
            isEmitting = emitsPetals
            if emitsPetals {
                streams = [Stream(id: nextStreamID, startTime: nil, stopTime: nil)]
                nextStreamID += 1
            }
            return
        }
        guard wasEmitting != emitsPetals else { return }

        isEmitting = emitsPetals
        streams.removeAll { stream in
            guard let stopTime = stream.stopTime else { return false }
            return time - stopTime >= 20
        }

        if emitsPetals {
            streams.append(Stream(
                id: nextStreamID,
                startTime: time,
                stopTime: nil
            ))
            nextStreamID += 1
        } else {
            for index in streams.indices where streams[index].stopTime == nil {
                streams[index].stopTime = time
            }
        }
    }
}

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
    let emitsPetals: Bool
    @Binding private var simulationTime: Double
    @Binding private var flowState: SakuraPetalFlowState

    private let configuration = Configuration()
    private let petals: [Petal]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock: SimulationClock

    init(
        windStrength: Double,
        startsFilled: Bool = true,
        simulationTime: Binding<Double>,
        emitsPetals: Bool = true,
        flowState: Binding<SakuraPetalFlowState> = .constant(.initiallyEmitting)
    ) {
        self.windStrength = windStrength
        self.startsFilled = startsFilled
        self.emitsPetals = emitsPetals
        _simulationTime = simulationTime
        _flowState = flowState
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
                    ForEach(flowState.streams) { stream in
                        ForEach(petals) { petal in
                            petalView(
                                petal,
                                canvasSize: proxy.size,
                                time: currentTime,
                                stream: stream
                            )
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            flowState.reconcile(emitsPetals: emitsPetals, at: clock.time)
        }
        .onChange(of: emitsPetals) { _, isEmitting in
            flowState.reconcile(emitsPetals: isEmitting, at: clock.time)
        }
        .onDisappear {
            simulationTime = clock.time
        }
    }

    private func petalView(
        _ petal: Petal,
        canvasSize: CGSize,
        time: TimeInterval,
        stream: SakuraPetalFlowState.Stream
    ) -> some View {
        let startsWithPetals = startsFilled && stream.startTime == nil
        let elapsedTime = time - (stream.startTime ?? 0)
        let entryDelay = startsWithPetals
            ? 0
            : petal.phase * configuration.initialArrivalSpread
        let rawProgress = startsWithPetals
            ? elapsedTime / petal.cycleDuration + petal.phase
            : (elapsedTime - entryDelay) / petal.cycleDuration
        let hasEntered = rawProgress >= 0
        let progress = hasEntered
            ? rawProgress - floor(rawProgress)
            : 0
        let wasInFlightAtStop: Bool
        if let stopTime = stream.stopTime {
            let stopElapsedTime = stopTime - (stream.startTime ?? 0)
            let stopProgress = startsWithPetals
                ? stopElapsedTime / petal.cycleDuration + petal.phase
                : (stopElapsedTime - entryDelay) / petal.cycleDuration
            wasInFlightAtStop = stopProgress >= 0
                && floor(rawProgress) == floor(stopProgress)
        } else {
            wasInFlightAtStop = true
        }
        let petalSize = configuration.minimumPetalSize
            + (configuration.maximumPetalSize - configuration.minimumPetalSize)
            * petal.sizeFactor

        let horizontalDistance = canvasSize.width + petalSize * 2
        let x = canvasSize.width + petalSize
            - progress * horizontalDistance

        let startingAreaHeight = startsWithPetals
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
            .opacity(hasEntered && wasInFlightAtStop ? edgeFade * 0.82 : 0)
            .position(x: x, y: y)
    }

    private static func random(_ index: Int, salt: Int) -> Double {
        let value = sin(Double(index * 97 + salt * 53)) * 43_758.5453
        return value - floor(value)
    }
}
