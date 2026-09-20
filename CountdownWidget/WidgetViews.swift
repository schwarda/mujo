import SwiftUI
import WidgetKit

struct DigitalHomeScreenView: View {
    let entry: CountdownProvider.Entry

    var body: some View {
        VStack(spacing: 6) {
            Text(
                entry.isEstimateAvailable
                    ? "R e m a i n i n g"
                    : "Updating…"
            )
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

            if entry.isEstimateAvailable {
                GlassText(value: entry.remainingTime.formatted(), size: 68)
            } else {
                Text("Waiting for data…")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .foregroundStyle(.secondary)
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

                if entry.remainingTime <= 0 {
                    GlassText(value: "Ø")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Remaining: \(entry.remainingTime.formatted())")
        } else {
            Text("Waiting for data…")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
                    size: 40
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Remaining: \(entry.remainingTime.formatted())")
        } else {
            Text("Waiting for data…")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct LockScreenRectangularView: View {
    let entry: CountdownProvider.Entry

    var body: some View {
        ZStack {
            if entry.isEstimateAvailable {
                Text("Mujø · \(entry.remainingTime.formatted())")
                    .font(.system(
                        size: 16,
                        design: .rounded
                    ))
            } else {
                Text("Ø Waiting for data…")
                    .font(.system(
                        size: 16,
                        design: .rounded
                    ))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LockScreenCircularView: View {
    let entry: CountdownProvider.Entry

    private var remainingFraction: Double {
        min(1, max(0, entry.remainingTime / max(1, entry.dailyLimit)))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    .quaternary,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )

            Circle()
                .trim(
                    from: 0,
                    to: entry.isEstimateAvailable ? remainingFraction : 1
                )
                .stroke(
                    .primary,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if entry.isEstimateAvailable {
                Text(entry.remainingTime.formatted())
                    .font(.system(
                        size: 16,
                        weight: .semibold,
                        design: .rounded
                    ))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .monospacedDigit()
            } else {
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
        if entry.isEstimateAvailable {
            Text("·  \(entry.remainingTime.formatted()) remaining")
                .font(MujoTheme.mediumFont(
                    size: 12,
                    relativeTo: .caption
                ))
        } else {
            Text("Ø Waiting for data…")
                .font(MujoTheme.mediumFont(
                    size: 12,
                    relativeTo: .caption
                ))
        }
    }
}

#Preview(as: .systemSmall) {
    GradientDigitalWidget()
} timeline: {
    CountdownEntry(
        date: .now,
        remainingTime: 10 * 60,
        dailyLimit: 2 * 60 * 60,
        isEstimateAvailable: true
    )
}
