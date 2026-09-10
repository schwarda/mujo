//
//  CountdownWidget.swift
//  CountdownWidget
//
//  Created by Lopk Art on 09/09/2026.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            configuration: ConfigurationAppIntent(),
            remainingTime: 3 * 60 * 60 + 42 * 60,
            isEstimateAvailable: true
        )
    }

    func snapshot(
        for configuration: ConfigurationAppIntent,
        in context: Context
    ) async -> SimpleEntry {
        SimpleEntry(
            date: .now,
            configuration: configuration,
            estimate: loadEstimate()
        )
    }

    func timeline(
        for configuration: ConfigurationAppIntent,
        in context: Context
    ) async -> Timeline<SimpleEntry> {
        let now = Date.now
        let entry = SimpleEntry(
            date: now,
            configuration: configuration,
            estimate: loadEstimate(at: now)
        )
        let nextDay = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: now)
        ) ?? now.addingTimeInterval(24 * 60 * 60)

        return Timeline(
            entries: [entry],
            policy: .after(nextDay)
        )
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

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let remainingTime: TimeInterval
    let isEstimateAvailable: Bool

    init(
        date: Date,
        configuration: ConfigurationAppIntent,
        remainingTime: TimeInterval,
        isEstimateAvailable: Bool
    ) {
        self.date = date
        self.configuration = configuration
        self.remainingTime = remainingTime
        self.isEstimateAvailable = isEstimateAvailable
    }

    fileprivate init(
        date: Date,
        configuration: ConfigurationAppIntent,
        estimate: UsageEstimate
    ) {
        self.init(
            date: date,
            configuration: configuration,
            remainingTime: estimate.remainingTime,
            isEstimateAvailable: estimate.isAvailable
        )
    }
}

struct CountdownWidgetEntryView: View {
    var entry: Provider.Entry

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
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: Provider()
        ) { entry in
            CountdownWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }
}

#Preview(as: .systemSmall) {
    CountdownWidget()
} timeline: {
    SimpleEntry(
        date: .now,
        configuration: .smiley,
        remainingTime: 3 * 60 * 60 + 42 * 60,
        isEstimateAvailable: true
    )
}
