//
//  WidgetUsageSnapshotLoader.swift
//  Mujo
//

import Foundation

struct WidgetUsageSnapshotLoader {
    private let defaults: UserDefaults?

    init(defaults: UserDefaults?) {
        self.defaults = defaults
    }

    func load() -> WidgetUsageSnapshot {
        WidgetUsageSnapshot(
            storedDailyLimit: defaults?.double(
                forKey: AppConfiguration.DefaultsKey.dailyLimit
            ) ?? 0,
            estimatedUsedTime: defaults?.double(
                forKey: AppConfiguration.DefaultsKey.estimatedUsedTime
            ) ?? 0,
            estimateDay: defaults?.double(
                forKey: AppConfiguration.DefaultsKey.lastCheckpointResetDay
            ) ?? 0,
            checkpointTimeZoneIdentifier: defaults?.string(
                forKey: AppConfiguration.DefaultsKey
                    .lastCheckpointTimeZoneIdentifier
            ),
            monitoringStartedAt: defaults?.double(
                forKey: AppConfiguration.DefaultsKey.usageMonitoringStartedAt
            ) ?? 0,
            hasCheckpoint: defaults?.bool(
                forKey: AppConfiguration.DefaultsKey.hasUsageCheckpoint
            ) ?? false
        )
    }
}
