//
//  CountdownWidget.swift
//  CountdownWidget
//
//  Created by Lopk Art on 09/09/2026.
//

import SwiftUI
import WidgetKit

struct CountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(
            date: Date(),
            remainingTime: 3 * 60 * 60 + 42 * 60,
            isEstimateAvailable: true
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (CountdownEntry) -> Void
    ) {
        completion(CountdownEntry(
            date: .now,
            estimate: loadEstimate()
        ))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<CountdownEntry>) -> Void
    ) {
        let now = Date.now
        let entry = CountdownEntry(
            date: now,
            estimate: loadEstimate(at: now)
        )
        let nextDay = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: now)
        ) ?? now.addingTimeInterval(24 * 60 * 60)

        completion(Timeline(
            entries: [entry],
            policy: .after(nextDay)
        ))
    }

    private func loadEstimate(at date: Date = .now) -> UsageEstimate {
        let defaults = UserDefaults(
            suiteName: "group.AikariStudio.Mujo.shared"
        )

        let storedLimit = defaults?.double(
            forKey: "dailyLimitSeconds"
        ) ?? 0

        let dailyLimit = storedLimit > 0
            ? storedLimit
            : 5 * 60 * 60

        let usedTime = defaults?.double(
            forKey: "estimatedUsedTimeSeconds"
        ) ?? 0
        let estimateDay = defaults?.double(
            forKey: "lastCheckpointResetDay"
        ) ?? 0
        let monitoringStartedAt = defaults?.double(
            forKey: "usageMonitoringStartedAt"
        ) ?? 0
        let hasCheckpoint = defaults?.bool(
            forKey: "hasUsageCheckpoint"
        ) ?? false
        let today = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        let monitoringPredatesToday = monitoringStartedAt > 0
            && monitoringStartedAt <= today
        let estimateWasResetToday = estimateDay == today
        let canUseStoredEstimate = estimateWasResetToday
            && (hasCheckpoint || monitoringPredatesToday)
        let canAssumeZeroUsage = !estimateWasResetToday
            && monitoringPredatesToday

        guard canUseStoredEstimate || canAssumeZeroUsage else {
            return UsageEstimate(
                remainingTime: dailyLimit,
                isAvailable: false
            )
        }

        let validUsedTime = canUseStoredEstimate ? usedTime : 0

        return UsageEstimate(
            remainingTime: max(0, dailyLimit - validUsedTime),
            isAvailable: true
        )
    }
}

private struct UsageEstimate {
    let remainingTime: TimeInterval
    let isAvailable: Bool
}

struct CountdownEntry: TimelineEntry {
    let date: Date
    let remainingTime: TimeInterval
    let isEstimateAvailable: Bool

    init(
        date: Date,
        remainingTime: TimeInterval,
        isEstimateAvailable: Bool
    ) {
        self.date = date
        self.remainingTime = remainingTime
        self.isEstimateAvailable = isEstimateAvailable
    }

    fileprivate init(
        date: Date,
        estimate: UsageEstimate
    ) {
        self.init(
            date: date,
            remainingTime: estimate.remainingTime,
            isEstimateAvailable: estimate.isAvailable
        )
    }
}

struct CountdownWidgetEntryView: View {
    let entry: CountdownProvider.Entry

    var body: some View {
        VStack(spacing: 6) {
            Text(
                entry.isEstimateAvailable
                    ? "Approx. remaining"
                    : "Screen Time estimate"
            )
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            if entry.isEstimateAvailable {
                GlassText(value: entry.remainingTime.formatted(), size: 48)
            } else {
                Text("Waiting for data")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct CountdownWidget: Widget {
    let kind: String = "CountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: CountdownProvider()
        ) { entry in
            CountdownWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Mujø Remaining Time")
        .description("Shows your approximate Screen Time remaining today.")
    }
}

#Preview(as: .systemSmall) {
    CountdownWidget()
} timeline: {
    CountdownEntry(
        date: .now,
        remainingTime: 3 * 60 * 60 + 42 * 60,
        isEstimateAvailable: true
    )
}
