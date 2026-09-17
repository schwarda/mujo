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
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mujø · remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(timeText(context.state.remainingMinutes))
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                Spacer()

                Text(context.state.updatedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .activityBackgroundTint(.pink.opacity(0.12))
            .activitySystemActionForegroundColor(.pink)
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
