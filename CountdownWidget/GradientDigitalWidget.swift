//
//  GradientDigitalWidget.swift
//  Mujo
//

import SwiftUI
import WidgetKit

struct GradientDigitalWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: AppConfiguration.gradientDigitalWidgetKind,
            provider: CountdownProvider()
        ) { entry in
            GradientDigitalHomeScreenView(entry: entry)
                .unredacted()
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Mujø Time & Gradient")
        .description(
            "See what remains at a glance, with the remaining time shown in "
                + "the center."
        )
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    GradientDigitalWidget()
} timeline: {
    CountdownEntry(
        date: .now,
        remainingTime: 60 * 60,
        dailyLimit: 2 * 60 * 60,
        isEstimateAvailable: true
    )
}
