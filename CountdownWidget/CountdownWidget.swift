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
        let plan = makePlan(at: .now)
        completion(CountdownEntry(plan: plan))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<CountdownEntry>) -> Void
    ) {
        let now = Date.now
        let plan = makePlan(at: now)

        completion(Timeline(
            entries: [CountdownEntry(plan: plan)],
            policy: .after(plan.reloadAfter)
        ))
    }

    private func makePlan(at date: Date) -> WidgetTimelinePlan {
        let defaults = UserDefaults(
            suiteName: AppConfiguration.appGroupIdentifier
        )
        let snapshot = WidgetUsageSnapshotLoader(defaults: defaults).load()

        return WidgetTimelinePlanner.makePlan(from: snapshot, at: date)
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

    fileprivate init(plan: WidgetTimelinePlan) {
        self.init(
            date: plan.date,
            remainingTime: plan.estimate.remainingTime,
            isEstimateAvailable: plan.estimate.isAvailable
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
