//
//  TimeDial.swift
//  Mujo
//

import SwiftUI
import UIKit

struct TimeDial: View {
    private struct Configuration {
        // Change these values to tune the dial.
        let diameter: CGFloat = 200
        let stepsPerTurn = 60
        let minutesPerStep = 5
        let minimumMinutes = 5
        let maximumMinutes = 12 * 60

        // Everything below is derived from the values above.
        var radius: CGFloat { diameter / 2 }
        var center: CGPoint { CGPoint(x: radius, y: radius) }
        var degreesPerStep: Double { 360 / Double(stepsPerTurn) }
        var majorTickFrequency: Int { max(1, stepsPerTurn / 12) }
        var tickOffset: CGFloat { -diameter * 0.431 }
        var majorTickWidth: CGFloat { diameter * 0.0216 }
        var minorTickWidth: CGFloat { diameter * 0.0108 }
        var majorTickHeight: CGFloat { diameter * 0.0647 }
        var minorTickHeight: CGFloat { diameter * 0.0431 }
        var symbolFontSize: CGFloat { diameter * 0.108 }
        var timeFontSize: CGFloat { diameter * 0.153 }
        var hintFontSize: CGFloat { diameter * 0.6 }
    }

    @Binding var minutes: Int
    @Binding var windStrength: Double
    let onValueChange: (Int) -> Void
    let onCommit: (Int) -> Void

    private let configuration = Configuration()

    @State private var previousAngle: Double?
    @State private var unconsumedRotation = 0.0
    @State private var visualRotation = 0.0
    @State private var previousSampleTime: TimeInterval?
    @State private var hintIsMoving = false
    @AppStorage("hasUsedCenteredTimeDialHint")
    private var hasUsedTimeDial = false

    var body: some View {
        ZStack {
            tickMarks
                .rotationEffect(.degrees(visualRotation))

            if !hasUsedTimeDial {
                rotationHint
            }

            Text(formattedTime)
                .font(.system(
                    size: configuration.timeFontSize,
                    weight: .semibold,
                    design: .rounded
                ))
                .monospacedDigit()
                .foregroundStyle(.tint)
        }
        .frame(
            width: configuration.diameter,
            height: configuration.diameter
        )
        .glassEffect(.clear.interactive(), in: .circle)
        .contentShape(.circle)
        .gesture(rotationGesture)
        .sensoryFeedback(
            .impact(flexibility: .rigid, intensity: 1),
            trigger: minutes
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Denný čas")
        .accessibilityValue(formattedTime)
        .accessibilityAdjustableAction { direction in
            hasUsedTimeDial = true

            switch direction {
            case .increment:
                changeMinutes(by: configuration.minutesPerStep)
            case .decrement:
                changeMinutes(by: -configuration.minutesPerStep)
            @unknown default:
                break
            }

            onCommit(minutes)
        }
        .onAppear {
            guard !hasUsedTimeDial else { return }

            withAnimation(
                .easeInOut(duration: 0.85)
                    .repeatForever(autoreverses: true)
            ) {
                hintIsMoving = true
            }
        }
    }

    private var rotationHint: some View {
        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
            .font(.system(
                size: configuration.hintFontSize,
                weight: .semibold
            ))
            .foregroundStyle(.tint)
            .opacity(hintIsMoving ? 0.34 : 0.14)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .symbolEffect(
                .rotate,
                options: .speed(0.5)
            )
    }

    private var tickMarks: some View {
        ZStack {
            ForEach(0..<configuration.stepsPerTurn, id: \.self) { index in
                let isMajorTick = index.isMultiple(
                    of: configuration.majorTickFrequency
                )

                Capsule()
                    .fill(Color.accentColor.opacity(isMajorTick ? 0.75 : 0.28))
                    .frame(
                        width: isMajorTick
                            ? configuration.majorTickWidth
                            : configuration.minorTickWidth,
                        height: isMajorTick
                            ? configuration.majorTickHeight
                            : configuration.minorTickHeight
                    )
                    .offset(y: configuration.tickOffset)
                    .rotationEffect(
                        .degrees(Double(index) * configuration.degreesPerStep)
                    )
            }
        }
    }

    private var rotationGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let angle = atan2(
                    value.location.y - configuration.center.y,
                    value.location.x - configuration.center.x
                ) * 180 / .pi

                guard let previousAngle else {
                    self.previousAngle = angle
                    previousSampleTime = CACurrentMediaTime()
                    return
                }

                var delta = angle - previousAngle
                if delta > 180 { delta -= 360 }
                if delta < -180 { delta += 360 }

                self.previousAngle = angle
                unconsumedRotation += delta
                visualRotation += delta
                updateWindStrength(for: delta)

                while abs(unconsumedRotation) >= configuration.degreesPerStep {
                    if !hasUsedTimeDial {
                        withAnimation(.easeOut(duration: 0.2)) {
                            hasUsedTimeDial = true
                        }
                    }

                    let direction = unconsumedRotation > 0 ? 1 : -1
                    changeMinutes(
                        by: direction * configuration.minutesPerStep
                    )
                    unconsumedRotation -= Double(direction)
                        * configuration.degreesPerStep
                }
            }
            .onEnded { _ in
                previousAngle = nil
                previousSampleTime = nil
                unconsumedRotation = 0
                withAnimation(.easeOut(duration: 1.25)) {
                    windStrength = 0
                }
                onCommit(minutes)
            }
    }

    private var formattedTime: String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return String(format: "%d:%02d", hours, remainingMinutes)
    }

    private func changeMinutes(by amount: Int) {
        let newValue = min(
            configuration.maximumMinutes,
            max(configuration.minimumMinutes, minutes + amount)
        )
        guard newValue != minutes else { return }

        minutes = newValue
        onValueChange(newValue)
    }

    private func updateWindStrength(for angleDelta: Double) {
        let now = CACurrentMediaTime()
        guard let previousSampleTime else {
            self.previousSampleTime = now
            return
        }

        let elapsed = max(1.0 / 120.0, now - previousSampleTime)
        let angularVelocity = abs(angleDelta) / elapsed
        let newStrength = min(1, angularVelocity / 720)

        self.previousSampleTime = now
        windStrength = max(newStrength, windStrength * 0.82)
    }
}

#Preview {
    ContentView()
}
