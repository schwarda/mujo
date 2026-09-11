//
//  MujoShared.swift
//  Mujo
//

import Foundation

/// Values shared by the app and its extension processes.
enum MujoShared {
    nonisolated static let appGroupIdentifier =
        "group.AikariStudio.Mujo.shared"
    nonisolated static let defaultDailyLimit: TimeInterval = 2 * 60 * 60
    nonisolated static let widgetKind = "CountdownWidget"

    enum Reporting {
        nonisolated static let todayContextName = "mujo.today"
    }

    enum DefaultsKey {
        nonisolated static let dailyLimit = "dailyLimitSeconds"
        nonisolated static let previewDailyLimit =
            "previewDailyLimitSeconds"
        nonisolated static let estimatedUsedTime =
            "estimatedUsedTimeSeconds"
        nonisolated static let lastCheckpointResetDay =
            "lastCheckpointResetDay"
        nonisolated static let lastCheckpointTimeZoneIdentifier =
            "lastCheckpointTimeZoneIdentifier"
        nonisolated static let hasUsageCheckpoint = "hasUsageCheckpoint"
        nonisolated static let usageMonitoringStartedAt =
            "usageMonitoringStartedAt"
        nonisolated static let activityReportRequestID =
            "activityReportRequestID"
        nonisolated static let readyActivityReportRequestID =
            "readyActivityReportRequestID"
    }

    enum Monitoring {
        nonisolated static let usageActivityName = "mujo.usage"
        nonisolated static let limitActivityName = "mujo.limit"
        nonisolated static let usageEventPrefix = usageActivityName + "."
        nonisolated static let limitEventPrefix = limitActivityName + "."

        nonisolated static func usageEventName(minutes: Int) -> String {
            usageEventPrefix + String(minutes)
        }

        nonisolated static func limitEventName(seconds: Int) -> String {
            limitEventPrefix + String(seconds)
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

        nonisolated static func limitSeconds(
            from eventName: String
        ) -> TimeInterval? {
            guard let seconds = positiveIntegerSuffix(
                in: eventName,
                after: limitEventPrefix
            ) else {
                return nil
            }

            return TimeInterval(seconds)
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
