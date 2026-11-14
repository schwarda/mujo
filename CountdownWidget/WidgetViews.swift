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

private struct DigitalTimeColumn: View {
    let title: String
    let value: TimeInterval
    let timeSize: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            GlassText(value: value.formatted(), size: timeSize)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DigitalHomeScreenView: View {
    let entry: CountdownProvider.Entry

    var body: some View {
        Group {
            if entry.isEstimateAvailable {
                DigitalTimeColumn(
                    title: "R e m a i n i n g",
                    value: entry.remainingTime,
                    timeSize: 68
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(entry.remainingTime.accessibilityDuration) remaining")
            } else {
                HomeScreenUnavailableView(entry: entry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color("BackgroundColor"), for: .widget)
    }
}

struct UsedDigitalHomeScreenView: View {
    let entry: CountdownProvider.Entry

    var body: some View {
        Group {
            if entry.isEstimateAvailable {
                DigitalTimeColumn(
                    title: "U s e d",
                    value: entry.usedTime,
                    timeSize: 68
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(entry.usedTime.accessibilityDuration) used")
            } else {
                HomeScreenUnavailableView(entry: entry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color("BackgroundColor"), for: .widget)
    }
}

struct DigitalOverviewHomeScreenView: View {
    let entry: CountdownProvider.Entry

    var body: some View {
        Group {
            if entry.isEstimateAvailable {
                HStack(spacing: 16) {
                    DigitalTimeColumn(
                        title: "R e m a i n i n g",
                        value: entry.remainingTime,
                        timeSize: 54
                    )

                    DigitalTimeColumn(
                        title: "U s e d",
                        value: entry.usedTime,
                        timeSize: 54
                    )
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(entry.remainingTime.accessibilityDuration) remaining, \(entry.usedTime.accessibilityDuration) used"
                )
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
            .accessibilityLabel("\(entry.remainingTime.accessibilityDuration) remaining")
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
            .accessibilityLabel("\(entry.remainingTime.accessibilityDuration) remaining")
        } else {
            HomeScreenUnavailableView(entry: entry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

enum LockScreenTimeMetric {
    case remaining
    case used

    func duration(in entry: CountdownEntry) -> TimeInterval {
        switch self {
        case .remaining: entry.remainingTime
        case .used: entry.usedTime
        }
    }

    func displayTime(in entry: CountdownEntry) -> String {
        let time = duration(in: entry).formatted()
        return self == .used && time == "Ø" ? "0:00" : time
    }

    func accessibilityLabel(for entry: CountdownEntry) -> Text {
        guard entry.isEstimateAvailable else {
            return Text(entry.unavailableMessage)
        }

        let time = duration(in: entry).accessibilityDuration
        switch self {
        case .remaining: return Text("\(time) remaining")
        case .used: return Text("\(time) used")
        }
    }
}

struct LockScreenRectangularView: View {
    let entry: CountdownProvider.Entry
    let metric: LockScreenTimeMetric

    var body: some View {
        VStack(spacing: -2) {
            Text(metric == .used ? "Used Time" : "Remaining")
                .font(.system(
                    size: 15,
                    weight: .semibold,
                    design: .rounded
                ))
                .foregroundStyle(.secondary)

            if entry.isEstimateAvailable {
                Text(metric.displayTime(in: entry))
                    .font(.system(
                        size: 25,
                        weight: .semibold,
                        design: .rounded
                    ))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .monospacedDigit()
                    .accessibilityLabel(metric.accessibilityLabel(for: entry))
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
    let metric: LockScreenTimeMetric

    private var fraction: Double {
        min(1, max(0, metric.duration(in: entry) / max(1, entry.dailyLimit)))
    }

    var body: some View {
        ZStack {
            if entry.isEstimateAvailable {
                LockScreenProgressRing(fraction: fraction)

                Text(metric.displayTime(in: entry))
                    .font(.system(
                        size: metric == .remaining && entry.isExhausted ? 24 : 16,
                        weight: .semibold,
                        design: .rounded
                    ))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .monospacedDigit()
                    .accessibilityLabel(metric.accessibilityLabel(for: entry))
            } else if entry.isAdjustingTimeZone {
                LockScreenProgressRing(fraction: 1)

                Image(systemName: "globe.europe.africa")
                    .font(.system(size: 23, weight: .semibold))
                    .accessibilityLabel(entry.unavailableMessage)
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
                    .accessibilityLabel(entry.unavailableMessage)
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

struct LockScreenInlineView: View {
    let entry: CountdownProvider.Entry
    let metric: LockScreenTimeMetric

    var body: some View {
        Group {
            if entry.isEstimateAvailable {
                let time = metric.displayTime(in: entry)
                switch metric {
                case .remaining: Text("·  \(time) remaining")
                case .used: Text("·  \(time) used")
                }
            } else if entry.isAdjustingTimeZone {
                Label(
                    entry.unavailableMessage,
                    systemImage: entry.unavailableSystemImage
                )
            } else {
                Text("·  \(entry.unavailableMessage)")
            }
        }
        .accessibilityLabel(metric.accessibilityLabel(for: entry))
        .font(MujoTheme.mediumFont(
            size: 12,
            relativeTo: .caption
        ))
    }
}
