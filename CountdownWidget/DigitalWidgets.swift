//
//  DigitalWidgets.swift
//  Mujo
//
//  Created by Aikari Studio on 18/09/2026.
//

import SwiftUI
import WidgetKit

struct DigitalWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: CountdownProvider.Entry
    let metric: LockScreenTimeMetric

    @ViewBuilder
    var body: some View {
        Group {
            switch widgetFamily {
            case .accessoryRectangular:
                LockScreenRectangularView(entry: entry, metric: metric)
            case .accessoryCircular:
                LockScreenCircularView(entry: entry, metric: metric)
            case .accessoryInline:
                LockScreenInlineView(entry: entry, metric: metric)
            default:
                switch metric {
                case .remaining:
                    DigitalHomeScreenView(entry: entry)
                case .used:
                    UsedDigitalHomeScreenView(entry: entry)
                }
            }
        }
        .unredacted()
    }
}

struct DigitalWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: AppConfiguration.widgetKind,
            provider: CountdownProvider()
        ) { entry in
            DigitalWidgetEntryView(entry: entry, metric: .remaining)
        }
        .configurationDisplayName("Mujø Remaining Time")
        .description("See how much of today's chosen time remains.")
        .supportedFamilies([
            .systemSmall,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}

struct UsedDigitalWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: AppConfiguration.usedDigitalWidgetKind,
            provider: CountdownProvider()
        ) { entry in
            DigitalWidgetEntryView(entry: entry, metric: .used)
        }
        .configurationDisplayName("Mujø Used Time")
        .description("See how much of today's chosen time you have used.")
        .supportedFamilies([
            .systemSmall,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}

struct DigitalOverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: AppConfiguration.digitalOverviewWidgetKind,
            provider: CountdownProvider()
        ) { entry in
            DigitalOverviewHomeScreenView(entry: entry)
                .unredacted()
        }
        .configurationDisplayName("Mujø Time Overview")
        .description("See today's remaining and used time together.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .accessoryRectangular) {
    DigitalWidget()
} timeline: {
    CountdownEntry(
        date: .now,
        remainingTime: 3 * 60 * 60 + 42 * 60,
        isEstimateAvailable: true
    )
}

#Preview(as: .accessoryCircular) {
    DigitalWidget()
} timeline: {
    CountdownEntry(
        date: .now,
        remainingTime: 1 * 60 * 60 + 30 * 60,
        isEstimateAvailable: true
    )
}
