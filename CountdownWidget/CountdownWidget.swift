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
        return CountdownEntry(
            date: Date(),
            remainingTime: 3 * 60 * 60 + 45 * 60,
            isEstimateAvailable: false
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
        let snapshot = UsageSnapshotLoader(defaults: defaults).load()

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
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: CountdownProvider.Entry

    @ViewBuilder
    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            HomeScreenWidgetView(entry: entry)
                .unredacted()

        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)
                .unredacted()

        case .accessoryCircular:
            LockScreenCircularView(entry: entry)
                .unredacted()

        case .accessoryInline:
            LockScreenInlineView(entry: entry)
                .unredacted()

        default:
            HomeScreenWidgetView(entry: entry)
                .unredacted()
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
        .supportedFamilies([
            .systemSmall,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}

#Preview(as: .accessoryRectangular) {
    CountdownWidget()
} timeline: {
    CountdownEntry(
        date: .now,
        remainingTime: 3 * 60 * 60 + 42 * 60,
        isEstimateAvailable: true
    )
}
