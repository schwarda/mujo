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

    private func loadEstimate(at date: Date = .now) -> WidgetUsageEstimate {
        let defaults = UserDefaults(
            suiteName: AppConfiguration.appGroupIdentifier
        )

        let snapshot = WidgetUsageSnapshot(
            storedDailyLimit: defaults?.double(
                forKey: AppConfiguration.DefaultsKey.dailyLimit
            ) ?? 0,
            estimatedUsedTime: defaults?.double(
                forKey: AppConfiguration.DefaultsKey.estimatedUsedTime
            ) ?? 0,
            estimateDay: defaults?.double(
                forKey: AppConfiguration.DefaultsKey.lastCheckpointResetDay
            ) ?? 0,
            checkpointTimeZoneIdentifier: defaults?.string(
                forKey: AppConfiguration.DefaultsKey.lastCheckpointTimeZoneIdentifier
            ),
            monitoringStartedAt: defaults?.double(
                forKey: AppConfiguration.DefaultsKey.usageMonitoringStartedAt
            ) ?? 0,
            hasCheckpoint: defaults?.bool(
                forKey: AppConfiguration.DefaultsKey.hasUsageCheckpoint
            ) ?? false
        )

        return WidgetUsageEstimator.estimate(from: snapshot, at: date)
    }
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
        estimate: WidgetUsageEstimate
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
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: AppConfiguration.widgetKind,
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
