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
                        
                        GlassText(value: timeText(context.state.remainingMinutes))
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
                            .font(.caption)

                        Text(timeText(context.state.remainingMinutes))
                            .font(.title.bold())
                            .monospacedDigit()
                    }
                }
            } compactLeading: {
                Text("Ø")
            } compactTrailing: {
                Text(timeText(context.state.remainingMinutes))
                    .font(.caption2)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } minimal: {
                Text("Ø")
            }
        }
    }

    private func timeText(_ minutes: Int) -> String {
        TimeInterval(max(0, minutes) * 60).formatted()
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
    as: .dynamicIsland(.compact),
    using: RemainingTimeActivityAttributes(limitMinutes: 120)
) {
    RemainingTimeLiveActivity()
} contentStates: {
    RemainingTimeActivityAttributes.ContentState(
        remainingMinutes: 15,
        updatedAt: .now
    )
}
