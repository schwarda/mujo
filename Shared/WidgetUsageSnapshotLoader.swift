//
//  WidgetUsageSnapshotLoader.swift
//  Mujo
//

import Foundation

struct UsageSnapshotLoader {
    private let defaults: UserDefaults?

    init(defaults: UserDefaults?) {
        self.defaults = defaults
    }

    func load() -> UsageSnapshot {
        let storedLimit = normalizedStoredLimit()
        let estimatedUsage = normalizedStoredUsage()

        return UsageSnapshot(
            storedDailyLimit: storedLimit,
            estimatedUsedTime: estimatedUsage,
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

    private func normalizedStoredLimit() -> TimeInterval {
        guard let defaults else { return 0 }
        let key = AppConfiguration.DefaultsKey.dailyLimit
        let stored = defaults.double(forKey: key)
        guard stored > 0 else { return 0 }

        let normalized = AppConfiguration.DailyLimit.normalizedLimit(stored)
        if normalized != stored {
            defaults.set(normalized, forKey: key)
        }
        return normalized
    }

    private func normalizedStoredUsage() -> TimeInterval {
        guard let defaults else { return 0 }
        let key = AppConfiguration.DefaultsKey.estimatedUsedTime
        let stored = defaults.double(forKey: key)
        let normalized = AppConfiguration.DailyLimit.normalizedUsage(stored)
        if normalized != stored {
            defaults.set(normalized, forKey: key)
        }
        return normalized
    }
}

typealias WidgetUsageSnapshotLoader = UsageSnapshotLoader
