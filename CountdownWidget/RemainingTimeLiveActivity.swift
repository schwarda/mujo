//
//  RemainingTimeLiveActivity.swift
//  Mujo
//
//  Created by Aikari Studio on 16/09/2026.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct RemainingTimeLiveActivity: Widget {
    private let dynamicIslandColor = Color("RemainingColor")

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RemainingTimeActivityAttributes.self) { context in
            ZStack() {
                HStack(alignment: .center) {
                    VStack(spacing: 4) {
                        Text("Mujø · remaining")
                            .font(MujoTheme.italicFont(
                                size: 14,
                                relativeTo: .body
                            ))
                            .foregroundStyle(.secondary)
                        
                        GlassText(
                            value: remainingTimeText(
                                context.state.remainingMinutes
                            )
                        )
                            .monospacedDigit()
                    }
                }
                .padding()
                .activityBackgroundTint(.pink.opacity(0.1))
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text("Mujø · remaining")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(dynamicIslandColor)

                        Text(remainingTimeText(context.state.remainingMinutes))
                            .font(.system(
                                .title,
                                design: .rounded,
                                weight: .bold
                            ))
                            .monospacedDigit()
                            .foregroundStyle(dynamicIslandColor)
                    }
                }
            } compactLeading: {
                DynamicIslandProgressRing(
                    remainingMinutes: context.state.remainingMinutes,
                    limitMinutes: context.attributes.limitMinutes,
                    color: dynamicIslandColor
                )
                .frame(width: 18, height: 18)
                .padding(.trailing, 4)
            } compactTrailing: {
                dynamicIslandMinutes(context.state.remainingMinutes)
            } minimal: {
                ZStack {
                    DynamicIslandProgressStroke(
                        remainingMinutes: context.state.remainingMinutes,
                        limitMinutes: context.attributes.limitMinutes,
                        color: dynamicIslandColor
                    )

                    dynamicIslandMinutes(context.state.remainingMinutes)
                        .padding(6)
                }
            }
            .keylineTint(dynamicIslandColor)
        }
    }

    private func minutesText(_ minutes: Int) -> String {
        String(max(0, minutes))
    }

    private func remainingTimeText(_ minutes: Int) -> String {
        let minutes = max(0, minutes)
        guard minutes > 0 else { return "Ø" }
        return "\(minutes) min"
    }

    private func dynamicIslandMinutes(_ minutes: Int) -> some View {
        Text(minutesText(minutes))
            .font(.system(.caption2, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(dynamicIslandColor)
    }
}

private struct DynamicIslandProgressStroke: View {
    let remainingMinutes: Int
    let limitMinutes: Int
    let color: Color

    private var remainingFraction: Double {
        min(
            1,
            max(0, Double(remainingMinutes) / Double(max(1, limitMinutes)))
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    color.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )

            Circle()
                .trim(from: 0, to: remainingFraction)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct DynamicIslandProgressRing: View {
    let remainingMinutes: Int
    let limitMinutes: Int
    let color: Color

    private var remainingFraction: Double {
        min(
            1,
            max(0, Double(remainingMinutes) / Double(max(1, limitMinutes)))
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 1, lineCap: .round)
                )

            DynamicIslandProgressSlice(fraction: remainingFraction)
                .fill(color)
        }
    }
}

private struct DynamicIslandProgressSlice: Shape {
    let fraction: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()

        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * fraction),
            clockwise: false
        )
        path.closeSubpath()

        return path
    }
}

#Preview(
    "Lock Screen",
    as: .content,
    using: RemainingTimeActivityAttributes(limitMinutes: 120)
) {
    RemainingTimeLiveActivity()
} contentStates: {
    RemainingTimeActivityAttributes.ContentState(
        remainingMinutes: 15,
        updatedAt: .now
    )
    RemainingTimeActivityAttributes.ContentState(
        remainingMinutes: 7,
        updatedAt: .now
    )
    RemainingTimeActivityAttributes.ContentState(
        remainingMinutes: 0,
        updatedAt: .now
    )
}

#Preview(
    "Dynamic Island Compact",
    as: .dynamicIsland(.minimal),
    using: RemainingTimeActivityAttributes(limitMinutes: 120)
) {
    RemainingTimeLiveActivity()
} contentStates: {
    RemainingTimeActivityAttributes.ContentState(
        remainingMinutes: 15,
        updatedAt: .now
    )
}
