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
    }
}
