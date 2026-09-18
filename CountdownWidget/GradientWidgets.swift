//
//  GradientWidgets.swift
//  Mujo
//
//  Created by Aikari Studio on 18/09/2026.
//

import SwiftUI
import WidgetKit

struct GradientWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: AppConfiguration.gradientWidgetKind,
            provider: CountdownProvider()
        ) { entry in
            GradientHomeScreenView(entry: entry)
                .unredacted()
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Mujø Time Balance")
        .description("Shows how much of today's screen time remains.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    GradientWidget()
} timeline: {
    CountdownEntry(
        date: .now,
        remainingTime: 60 * 60,
        dailyLimit: 2 * 60 * 60,
        isEstimateAvailable: true
    )
}
