#if DEBUG
import DeviceActivity
import ExtensionKit
import Foundation
import SwiftUI

struct ScreenTimeDiagnosticsConfiguration: Equatable, Sendable {
    struct Source: Equatable, Identifiable, Sendable {
        let id: Int
        let deviceName: String
        let deviceModel: String
        let userRole: String
        let lastUpdatedDate: Date
        let segmentCount: Int
    }

    struct Day: Equatable, Identifiable, Sendable {
        let date: Date
        let duration: TimeInterval
        let rawSegmentCount: Int

        var id: Date { date }
    }

    let sources: [Source]
    let days: [Day]
    let rawSegmentCount: Int

    var totalDuration: TimeInterval {
        days.reduce(0) { $0 + $1.duration }
    }

    var positiveDayCount: Int {
        days.count { $0.duration > 0 }
    }

    var zeroDayCount: Int {
        days.count - positiveDayCount
    }

    var onboardingAverage: TimeInterval? {
        guard !days.isEmpty, totalDuration > 0 else { return nil }
        return totalDuration / Double(days.count)
    }

    var onboardingCopyBranch: String {
        guard onboardingAverage != nil else { return "unavailable" }
        if days.count >= OnboardingProjectionRules.recentDayCount {
            return "over the last 7 days"
        }
        return "based on \(days.count) available days"
    }
}

struct ScreenTimeDiagnosticsReport: nonisolated DeviceActivityReportScene {
    let context = DeviceActivityReport.Context("Mujo Diagnostics")
    let content: (
        ScreenTimeDiagnosticsConfiguration
    ) -> ScreenTimeDiagnosticsReportView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> ScreenTimeDiagnosticsConfiguration {
        let calendar = Calendar.autoupdatingCurrent
        var sources: [ScreenTimeDiagnosticsConfiguration.Source] = []
        var durationByDay: [Date: TimeInterval] = [:]
        var segmentCountByDay: [Date: Int] = [:]
        var rawSegmentCount = 0

        for await activityData in data {
            guard !Task.isCancelled else {
                return ScreenTimeDiagnosticsConfiguration(
                    sources: [],
                    days: [],
                    rawSegmentCount: 0
                )
            }

            var sourceSegmentCount = 0
            for await segment in activityData.activitySegments {
                guard !Task.isCancelled else { break }
                let day = calendar.startOfDay(
                    for: segment.dateInterval.start
                )
                durationByDay[day, default: 0] += segment.totalActivityDuration
                segmentCountByDay[day, default: 0] += 1
                sourceSegmentCount += 1
                rawSegmentCount += 1
            }

            sources.append(
                ScreenTimeDiagnosticsConfiguration.Source(
                    id: sources.count,
                    deviceName: activityData.device.name ?? "Unnamed device",
                    deviceModel: deviceModel(activityData.device.model),
                    userRole: userRole(activityData.user.role),
                    lastUpdatedDate: activityData.lastUpdatedDate,
                    segmentCount: sourceSegmentCount
                )
            )
        }

        let days = durationByDay.keys.sorted().map { day in
            ScreenTimeDiagnosticsConfiguration.Day(
                date: day,
                duration: durationByDay[day, default: 0],
                rawSegmentCount: segmentCountByDay[day, default: 0]
            )
        }

        return ScreenTimeDiagnosticsConfiguration(
            sources: sources,
            days: days,
            rawSegmentCount: rawSegmentCount
        )
    }

    private func deviceModel(
        _ model: DeviceActivityData.Device.Model
    ) -> String {
        switch model {
        case .iPhone: "iPhone"
        case .iPod: "iPod"
        case .iPad: "iPad"
        case .mac: "Mac"
        @unknown default: "Unknown"
        }
    }

    private func userRole(
        _ role: DeviceActivityData.User.FamilyRole
    ) -> String {
        switch role {
        case .individual: "individual"
        case .child: "child"
        @unknown default: "unknown"
        }
    }
}

struct ScreenTimeDiagnosticsReportView: View {
    let configuration: ScreenTimeDiagnosticsConfiguration

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summary
                sources
                days
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .font(.caption.monospaced())
        .textSelection(.enabled)
    }

    private var summary: some View {
        diagnosticsSection("Onboarding calculation") {
            diagnosticsRow("Source records", "\(configuration.sources.count)")
            diagnosticsRow("Raw segments", "\(configuration.rawSegmentCount)")
            diagnosticsRow("Distinct days", "\(configuration.days.count)")
            diagnosticsRow("Positive days", "\(configuration.positiveDayCount)")
            diagnosticsRow("Zero days", "\(configuration.zeroDayCount)")
            diagnosticsRow("Total", formatted(configuration.totalDuration))
            diagnosticsRow(
                "Average denominator",
                configuration.days.isEmpty
                    ? "—"
                    : "\(configuration.days.count) days"
            )
            diagnosticsRow(
                "Onboarding average",
                configuration.onboardingAverage.map(formatted) ?? "unavailable"
            )
            diagnosticsRow("Copy branch", configuration.onboardingCopyBranch)
        }
    }

    private var sources: some View {
        diagnosticsSection("Sources") {
            if configuration.sources.isEmpty {
                Text("No DeviceActivityData records returned.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(configuration.sources) { source in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(source.deviceName) · \(source.deviceModel)")
                            .fontWeight(.semibold)
                        Text("Role: \(source.userRole)")
                        Text("Last updated: \(formatted(source.lastUpdatedDate))")
                        Text("Segments: \(source.segmentCount)")
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private var days: some View {
        diagnosticsSection("Daily segments") {
            if configuration.days.isEmpty {
                Text("No daily segments returned.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(configuration.days) { day in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(day.date.formatted(
                            .dateTime.year().month(.twoDigits).day(.twoDigits)
                        ))
                        .fontWeight(.semibold)
                        Text("Duration: \(formatted(day.duration))")
                        Text("Zero duration: \(day.duration == 0 ? "yes" : "no")")
                        Text("Raw segments: \(day.rawSegmentCount)")
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private func diagnosticsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func diagnosticsRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func formatted(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3_600
        let minutes = totalSeconds % 3_600 / 60
        let seconds = totalSeconds % 60
        return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(
            date: .numeric,
            time: .standard
        )
    }
}
#endif
