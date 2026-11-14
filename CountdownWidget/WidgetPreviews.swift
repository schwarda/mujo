import SwiftUI
import WidgetKit

#if DEBUG
private enum WidgetPreviewEntry {
    static let used = CountdownEntry(
        date: .now,
        remainingTime: 2 * 60 * 60 + 15 * 60,
        usedTime: 45 * 60,
        dailyLimit: 3 * 60 * 60,
        isEstimateAvailable: true
    )

    static let noUsage = CountdownEntry(
        date: .now,
        remainingTime: 3 * 60 * 60,
        usedTime: 0,
        dailyLimit: 3 * 60 * 60,
        isEstimateAvailable: true
    )

    static let overLimit = CountdownEntry(
        date: .now,
        remainingTime: 0,
        usedTime: 3 * 60 * 60 + 15 * 60,
        dailyLimit: 3 * 60 * 60,
        isEstimateAvailable: true
    )

    static let remaining = CountdownEntry(
        date: .now,
        remainingTime: 1 * 60 * 60 + 30 * 60,
        dailyLimit: 3 * 60 * 60,
        isEstimateAvailable: true
    )

    static let exhausted = CountdownEntry(
        date: .now,
        remainingTime: 0,
        dailyLimit: 3 * 60 * 60,
        isEstimateAvailable: true
    )

    static let waiting = CountdownEntry(
        date: .now,
        remainingTime: 3 * 60 * 60,
        dailyLimit: 3 * 60 * 60,
        isEstimateAvailable: false,
        unavailableReason: .missingData
    )

    static let timeZoneChanged = CountdownEntry(
        date: .now,
        remainingTime: 3 * 60 * 60,
        dailyLimit: 3 * 60 * 60,
        isEstimateAvailable: false,
        unavailableReason: .timeZoneChanged
    )
}

#Preview("Time Home · Remaining", as: .systemSmall) {
    DigitalWidget()
} timeline: {
    WidgetPreviewEntry.remaining
}

#Preview("Time Home · Exhausted", as: .systemSmall) {
    DigitalWidget()
} timeline: {
    WidgetPreviewEntry.exhausted
}

#Preview("Time Home · Waiting", as: .systemSmall) {
    DigitalWidget()
} timeline: {
    WidgetPreviewEntry.waiting
}

#Preview("Time Home · Time Zone", as: .systemSmall) {
    DigitalWidget()
} timeline: {
    WidgetPreviewEntry.timeZoneChanged
}

#Preview("Used Time · Available", as: .systemSmall) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.remaining
}

#Preview("Used Time · Exhausted", as: .systemSmall) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.exhausted
}

#Preview("Used Time · Waiting", as: .systemSmall) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.waiting
}

#Preview("Used Time · Time Zone", as: .systemSmall) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.timeZoneChanged
}

#Preview("Time Overview · Available", as: .systemMedium) {
    DigitalOverviewWidget()
} timeline: {
    WidgetPreviewEntry.remaining
}

#Preview("Time Overview · Exhausted", as: .systemMedium) {
    DigitalOverviewWidget()
} timeline: {
    WidgetPreviewEntry.exhausted
}

#Preview("Time Overview · Waiting", as: .systemMedium) {
    DigitalOverviewWidget()
} timeline: {
    WidgetPreviewEntry.waiting
}

#Preview("Time Overview · Time Zone", as: .systemMedium) {
    DigitalOverviewWidget()
} timeline: {
    WidgetPreviewEntry.timeZoneChanged
}

#Preview("Gradient · Remaining", as: .systemSmall) {
    GradientWidget()
} timeline: {
    WidgetPreviewEntry.remaining
}

#Preview("Gradient · Exhausted", as: .systemSmall) {
    GradientWidget()
} timeline: {
    WidgetPreviewEntry.exhausted
}

#Preview("Gradient · Waiting", as: .systemSmall) {
    GradientWidget()
} timeline: {
    WidgetPreviewEntry.waiting
}

#Preview("Gradient · Time Zone", as: .systemSmall) {
    GradientWidget()
} timeline: {
    WidgetPreviewEntry.timeZoneChanged
}

#Preview("Time & Gradient · Remaining", as: .systemSmall) {
    GradientDigitalWidget()
} timeline: {
    WidgetPreviewEntry.remaining
}

#Preview("Time & Gradient · Exhausted", as: .systemSmall) {
    GradientDigitalWidget()
} timeline: {
    WidgetPreviewEntry.exhausted
}

#Preview("Time & Gradient · Waiting", as: .systemSmall) {
    GradientDigitalWidget()
} timeline: {
    WidgetPreviewEntry.waiting
}

#Preview("Time & Gradient · Time Zone", as: .systemSmall) {
    GradientDigitalWidget()
} timeline: {
    WidgetPreviewEntry.timeZoneChanged
}

#Preview("Lock Rectangular · Remaining", as: .accessoryRectangular) {
    DigitalWidget()
} timeline: {
    WidgetPreviewEntry.remaining
}

#Preview("Lock Rectangular · Exhausted", as: .accessoryRectangular) {
    DigitalWidget()
} timeline: {
    WidgetPreviewEntry.exhausted
}

#Preview("Lock Rectangular · Waiting", as: .accessoryRectangular) {
    DigitalWidget()
} timeline: {
    WidgetPreviewEntry.waiting
}

#Preview("Lock Rectangular · Time Zone", as: .accessoryRectangular) {
    DigitalWidget()
} timeline: {
    WidgetPreviewEntry.timeZoneChanged
}

#Preview("Lock Circular · Remaining", as: .accessoryCircular) {
    DigitalWidget()
} timeline: {
    WidgetPreviewEntry.remaining
}

#Preview("Lock Circular · Exhausted", as: .accessoryCircular) {
    DigitalWidget()
} timeline: {
    WidgetPreviewEntry.exhausted
}

#Preview("Lock Circular · Waiting", as: .accessoryCircular) {
    DigitalWidget()
} timeline: {
    WidgetPreviewEntry.waiting
}

#Preview("Lock Circular · Time Zone", as: .accessoryCircular) {
    DigitalWidget()
} timeline: {
    WidgetPreviewEntry.timeZoneChanged
}

#Preview("Lock Inline · Remaining", as: .accessoryInline) {
    DigitalWidget()
} timeline: {
    WidgetPreviewEntry.remaining
}

#Preview("Lock Inline · Exhausted", as: .accessoryInline) {
    DigitalWidget()
} timeline: {
    WidgetPreviewEntry.exhausted
}

#Preview("Lock Inline · Waiting", as: .accessoryInline) {
    DigitalWidget()
} timeline: {
    WidgetPreviewEntry.waiting
}

#Preview("Lock Inline · Time Zone", as: .accessoryInline) {
    DigitalWidget()
} timeline: {
    WidgetPreviewEntry.timeZoneChanged
}

#Preview("Used Time Lock Rectangular · Available", as: .accessoryRectangular) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.used
}

#Preview("Used Time Lock Rectangular · Zero", as: .accessoryRectangular) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.noUsage
}

#Preview("Used Time Lock Rectangular · Over Limit", as: .accessoryRectangular) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.overLimit
}

#Preview("Used Time Lock Rectangular · Waiting", as: .accessoryRectangular) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.waiting
}

#Preview("Used Time Lock Rectangular · Time Zone", as: .accessoryRectangular) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.timeZoneChanged
}

#Preview("Used Time Lock Circular · Available", as: .accessoryCircular) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.used
}

#Preview("Used Time Lock Circular · Zero", as: .accessoryCircular) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.noUsage
}

#Preview("Used Time Lock Circular · Over Limit", as: .accessoryCircular) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.overLimit
}

#Preview("Used Time Lock Circular · Waiting", as: .accessoryCircular) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.waiting
}

#Preview("Used Time Lock Circular · Time Zone", as: .accessoryCircular) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.timeZoneChanged
}

#Preview("Used Time Lock Inline · Available", as: .accessoryInline) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.used
}

#Preview("Used Time Lock Inline · Zero", as: .accessoryInline) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.noUsage
}

#Preview("Used Time Lock Inline · Over Limit", as: .accessoryInline) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.overLimit
}

#Preview("Used Time Lock Inline · Waiting", as: .accessoryInline) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.waiting
}

#Preview("Used Time Lock Inline · Time Zone", as: .accessoryInline) {
    UsedDigitalWidget()
} timeline: {
    WidgetPreviewEntry.timeZoneChanged
}
#endif
