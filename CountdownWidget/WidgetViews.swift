import SwiftUI
import WidgetKit

struct DigitalHomeScreenView: View {
    let entry: CountdownProvider.Entry

    var body: some View {
        VStack(spacing: 6) {
            Text(
                entry.isEstimateAvailable
                    ? "Remaining"
                    : "Screen Time estimate"
            )
            .font(MujoTheme.mediumFont(
                size: 12,
                relativeTo: .caption2
            ))
            .textCase(.uppercase)

            if entry.isEstimateAvailable {
                GlassText(value: entry.remainingTime.formatted(), size: 78)
            } else {
                Text("Waiting for data")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .foregroundStyle(.secondary)
    }
}

struct GradientHomeScreenView: View {
    let entry: CountdownProvider.Entry

    private let remainingColor = Color("RemainingColor")
    private let usedColor = Color("UsedColor")

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
                .init(color: usedColor, location: 0),
                .init(color: usedColor, location: transitionStart),
                .init(color: remainingColor, location: transitionEnd),
                .init(color: remainingColor, location: 1)
            ],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        ))
    }

    @ViewBuilder
    var body: some View {
        if entry.isEstimateAvailable {
            ZStack {
                Rectangle()
                    .fill(widgetFill)

                if entry.remainingTime <= 0 {
                    GlassText(value: "Ø")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Remaining: \(entry.remainingTime.formatted())")
        } else {
            Text("Waiting for data")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct LockScreenRectangularView: View {
    let entry: CountdownProvider.Entry

    var body: some View {
        if entry.isEstimateAvailable {
            Text("Mujø · \(entry.remainingTime.formatted())")
        } else {
            Text("Waiting for data")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct LockScreenCircularView: View {
    let entry: CountdownProvider.Entry

    var body: some View {
        if entry.isEstimateAvailable {
            Text(entry.remainingTime.formatted())
        } else {
            Text("-:-")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct LockScreenInlineView: View {
    let entry: CountdownProvider.Entry

    var body: some View {
        if entry.isEstimateAvailable {
            Text("Remaining: \(entry.remainingTime.formatted())")
        } else {
            Text("Waiting for data")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
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
