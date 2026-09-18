//
//  DigitalWidgets.swift
//  Mujo
//
//  Created by Aikari Studio on 18/09/2026.
//

import SwiftUI
import WidgetKit

struct CountdownWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: CountdownProvider.Entry

    @ViewBuilder
    var body: some View {
        Group {
            switch widgetFamily {
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

#Preview(as: .systemSmall) {
    CountdownWidget()
} timeline: {
    CountdownEntry(
        date: .now,
        remainingTime: 3 * 60 * 60 + 42 * 60,
        isEstimateAvailable: true
    )
}
