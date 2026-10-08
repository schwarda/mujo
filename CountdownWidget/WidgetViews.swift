import SwiftUI
import WidgetKit

private extension CountdownEntry {
    var unavailableSystemImage: String {
        isAdjustingTimeZone
            ? "globe.europe.africa"
            : "arrow.clockwise"
    }
}

private struct HomeScreenUnavailableView: View {
    let entry: CountdownProvider.Entry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: entry.unavailableSystemImage)
                .font(.system(size: 28, weight: .medium))

            Text(entry.unavailableMessage)
                .font(.system(
                    size: 16,
                    weight: .semibold,
                    design: .rounded
                ))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(
            MujoTheme.glassAccent.opacity(MujoTheme.secondaryTextOpacity)
        )
        .padding(.horizontal, 20)
    }
}

struct DigitalHomeScreenView: View {
    let entry: CountdownProvider.Entry

    var body: some View {
        Group {
            if entry.isEstimateAvailable {
                VStack(spacing: 6) {
                    Text("R e m a i n i n g")
                        .font(MujoTheme.mediumFont(
                            size: 12,
                            relativeTo: .caption2
                        ))
                        .textCase(.uppercase)
                        .foregroundStyle(
                            MujoTheme.glassAccent.opacity(
                                MujoTheme.secondaryTextOpacity
                            )
                        )

                    GlassText(value: entry.remainingTime.formatted(), size: 68)
                }
            } else {
                HomeScreenUnavailableView(entry: entry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color("BackgroundColor"), for: .widget)
    }
}

private struct GradientTimeBackground: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: CountdownProvider.Entry

    private var remainingColor: Color {
        renderingMode == .accented
            ? .white.opacity(0.65)
            : Color("RemainingColor")
    }

    private var usedColor: Color {
        renderingMode == .accented
            ? .white.opacity(0.08)
            : Color("UsedColor")
    }

    private var widgetFill: AnyShapeStyle {
        let dailyLimit = max(1, entry.dailyLimit)
        let remainingTime = min(max(0, entry.remainingTime), dailyLimit)
        let phaseMinutes = AppConfiguration.DailyLimit.displayResolutionMinutes(
            remainingTime: remainingTime,
            dailyLimit: dailyLimit
        )
        let transitionStart = max(
            0,
            (remainingTime - TimeInterval(phaseMinutes * 60)) / dailyLimit
        )
        let transitionEnd = remainingTime / dailyLimit

        return AnyShapeStyle(AngularGradient(
            stops: [
                .init(color: remainingColor, location: 0),
                .init(color: remainingColor, location: transitionStart),
                .init(color: usedColor, location: transitionEnd),
                .init(color: usedColor, location: 1)
            ],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        ))
    }

    var body: some View {
        Rectangle()
            .fill(widgetFill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct GradientHomeScreenView: View {
    let entry: CountdownProvider.Entry

    @ViewBuilder
    var body: some View {
        if entry.isEstimateAvailable {
            ZStack {
                GradientTimeBackground(entry: entry)

                if entry.isExhausted {
                    GlassText(value: "Ø")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Remaining: \(entry.remainingTime.formatted())")
        } else {
            HomeScreenUnavailableView(entry: entry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct GradientDigitalHomeScreenView: View {
    let entry: CountdownProvider.Entry

    @ViewBuilder
    var body: some View {
        if entry.isEstimateAvailable {
            ZStack {
                GradientTimeBackground(entry: entry)

                GlassText(
                    value: entry.remainingTime.formatted(),
                    size: entry.isExhausted ? 118 : 40
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Remaining: \(entry.remainingTime.formatted())")
        } else {
            HomeScreenUnavailableView(entry: entry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct LockScreenRectangularView: View {
    let entry: CountdownProvider.Entry

    var body: some View {
        VStack(spacing: -2) {
            Text("Mujø")
                .font(.system(
                    size: 15,
                    weight: .semibold,
                    design: .rounded
                ))
                .foregroundStyle(.secondary)

            if entry.isEstimateAvailable {
                Text(entry.remainingTime.formatted())
                    .font(.system(
                        size: 25,
                        weight: .semibold,
                        design: .rounded
                    ))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .monospacedDigit()
            } else {
                HStack(alignment: .center, spacing: 4) {
                    Image(systemName: entry.unavailableSystemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 16, height: 16, alignment: .center)

                    Text(entry.unavailableMessage)
                }
                .font(.system(
                    size: entry.isAdjustingTimeZone ? 16 : 21,
                    weight: .semibold,
                    design: .rounded
                ))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.clear, for: .widget)
    }
}

private struct LockScreenProgressRing: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    .quaternary,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    .primary,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

struct LockScreenCircularView: View {
    let entry: CountdownProvider.Entry

    private var remainingFraction: Double {
        min(1, max(0, entry.remainingTime / max(1, entry.dailyLimit)))
    }

    var body: some View {
        ZStack {
            if entry.isEstimateAvailable {
                LockScreenProgressRing(fraction: remainingFraction)

                Text(entry.remainingTime.formatted())
                    .font(.system(
                        size: entry.isExhausted ? 24 : 16,
                        weight: .semibold,
                        design: .rounded
                    ))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .monospacedDigit()
            } else if entry.isAdjustingTimeZone {
                LockScreenProgressRing(fraction: 1)

                Image(systemName: "globe.europe.africa")
                    .font(.system(size: 23, weight: .semibold))
            } else {
                LockScreenProgressRing(fraction: 1)

                Text("-:-")
                    .font(.system(
                        size: 16,
                        weight: .semibold,
                        design: .rounded
                    ))
                    .fontWeight(.black)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

struct LockScreenInlineView: View {
    let entry: CountdownProvider.Entry

    var body: some View {
        Group {
            if entry.isExhausted {
                Text("·  Ø remaining")
            } else if entry.isEstimateAvailable {
                Text("·  \(entry.remainingTime.formatted()) remaining")
            } else if entry.isAdjustingTimeZone {
                Label(
                    entry.unavailableMessage,
                    systemImage: entry.unavailableSystemImage
                )
            } else {
                Text("·  \(entry.unavailableMessage)")
            }
        }
        .font(MujoTheme.mediumFont(
            size: 12,
            relativeTo: .caption
        ))
    }
}

#if DEBUG
private enum WidgetPreviewEntry {
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
#endif
