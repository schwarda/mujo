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

    @ViewBuilder
    var body: some View {
        Group {
            switch widgetFamily {
            case .systemSmall:
                DigitalHomeScreenView(entry: entry)
            case .accessoryRectangular:
                LockScreenRectangularView(entry: entry)
            case .accessoryCircular:
                LockScreenCircularView(entry: entry)
            case .accessoryInline:
                LockScreenInlineView(entry: entry)
            default:
                DigitalHomeScreenView(entry: entry)
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
            DigitalWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Mujø Time")
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
            UsedDigitalHomeScreenView(entry: entry)
                .unredacted()
        }
        .configurationDisplayName("Mujø Used Time")
        .description("See how much of today's chosen time you have used.")
        .supportedFamilies([.systemSmall])
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
