//
//  AppConfiguration.swift
//  Mujo
//

import Foundation

/// Values shared by the app and its extension processes.
enum AppConfiguration {
    nonisolated static let appGroupIdentifier = "group.AikariStudio.Mujo.shared"
    nonisolated static let defaultDailyLimit: TimeInterval = 2 * 60 * 60
    nonisolated static let widgetKind = "CountdownWidget"
    nonisolated static let gradientWidgetKind = "GradientWidget"

    enum DailyLimit {
        nonisolated static let stepMinutes = 15
        nonisolated static let minimumMinutes = 15
        nonisolated static let maximumMinutes = 12 * 60

        nonisolated static func normalizedMinutes(_ minutes: Int) -> Int {
            let clamped = min(maximumMinutes, max(minimumMinutes, minutes))
            let roundedSteps = (clamped + stepMinutes / 2) / stepMinutes
            return min(
                maximumMinutes,
                max(minimumMinutes, roundedSteps * stepMinutes)
            )
        }

        nonisolated static func normalizedLimit(
            _ limit: TimeInterval
        ) -> TimeInterval {
            guard limit.isFinite, limit > 0 else {
                return AppConfiguration.defaultDailyLimit
            }

            let minutes = Int(limit / 60)
            let remainingSeconds = limit.truncatingRemainder(dividingBy: 60)
            let roundedMinutes = remainingSeconds >= 30
                ? minutes + 1
                : minutes
            return TimeInterval(normalizedMinutes(roundedMinutes) * 60)
        }

        nonisolated static func normalizedUsage(
            _ usage: TimeInterval
        ) -> TimeInterval {
            guard usage.isFinite, usage > 0 else { return 0 }
            return floor(usage / 60) * 60
        }

        nonisolated static func liveActivityWindowMinutes(
            forLimitMinutes minutes: Int
        ) -> Int {
            normalizedMinutes(minutes) >= 4 * 60 ? 30 : 15
        }

        nonisolated static func displayResolutionMinutes(
            remainingTime: TimeInterval,
            dailyLimit: TimeInterval
        ) -> Int {
            let finalWindowMinutes = liveActivityWindowMinutes(
                forLimitMinutes: Int(dailyLimit / 60)
            )
            return remainingTime <= TimeInterval(finalWindowMinutes * 60)
                ? 1
                : stepMinutes
        }
    }

    enum DefaultsKey {
        nonisolated static let dailyLimit = "dailyLimitSeconds"
        nonisolated static let previewDailyLimit = "previewDailyLimitSeconds"
        nonisolated static let estimatedUsedTime = "estimatedUsedTimeSeconds"
        nonisolated static let lastCheckpointResetDay = "lastCheckpointResetDay"
        nonisolated static let lastCheckpointTimeZoneIdentifier = "lastCheckpointTimeZoneIdentifier"
        nonisolated static let hasUsageCheckpoint = "hasUsageCheckpoint"
        nonisolated static let usageMonitoringStartedAt = "usageMonitoringStartedAt"
    }

    enum Monitoring {
        nonisolated static let usageActivityName = "mujo.usage"
        nonisolated static let legacyLimitActivityName = "mujo.limit"
        nonisolated static let usageEventPrefix = usageActivityName + "."
        nonisolated static let legacyNotificationActivityName = "mujo.notifications"

        nonisolated static func usageEventName(minutes: Int) -> String {
            usageEventPrefix + String(minutes)
        }

        nonisolated static func usageThresholdMinutes(
            forLimitMinutes minutes: Int
        ) -> [Int] {
            let limit = DailyLimit.normalizedMinutes(minutes)
            let invitation = max(
                1,
                limit - DailyLimit.liveActivityWindowMinutes(
                    forLimitMinutes: limit
                )
            )
            var thresholds = Set(stride(
                from: DailyLimit.stepMinutes,
                through: DailyLimit.maximumMinutes,
                by: DailyLimit.stepMinutes
            ))
            // Confirm the first usage checkpoint soon after monitoring starts.
            thresholds.insert(1)

            for usedMinutes in invitation...limit {
                thresholds.insert(usedMinutes)
            }

            return thresholds.sorted()
        }

        nonisolated static func usageCheckpointSeconds(
            from eventName: String
        ) -> TimeInterval? {
            guard let minutes = positiveIntegerSuffix(
                in: eventName,
                after: usageEventPrefix
            ) else {
                return nil
            }

            return TimeInterval(minutes) * 60
        }

        private nonisolated static func positiveIntegerSuffix(
            in value: String,
            after prefix: String
        ) -> Int? {
            guard value.hasPrefix(prefix),
                  let number = Int(value.dropFirst(prefix.count)),
                  number > 0
            else {
                return nil
            }

            return number
        }
    }
}
