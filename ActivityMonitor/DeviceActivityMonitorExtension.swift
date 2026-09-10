//
//  DeviceActivityMonitorExtension.swift
//  ActivityMonitor
//
//  Created by Lopk Art on 06/09/2026.
//

import DeviceActivity
import Foundation
import OSLog
import WidgetKit

extension DeviceActivityName {
    static let mujoUsage = Self("mujo.usage")
    static let mujoLimit = Self("mujo.limit")
}

private let logger = Logger(
    subsystem: "AikariStudio.Mujo",
    category: "ActivityMonitor"
)

private let appGroupIdentifier = "group.AikariStudio.Mujo.shared"
private let dailyLimitKey = "dailyLimitSeconds"
private let estimatedUsedTimeKey = "estimatedUsedTimeSeconds"
private let lastResetDayKey = "lastCheckpointResetDay"
private let dailyLimitReachedKey = "dailyLimitReached"
private let hasUsageCheckpointKey = "hasUsageCheckpoint"
private let estimateUpdatedAtKey = "usageEstimateUpdatedAt"

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            logger.error("App Group UserDefaults is unavailable")
            return
        }

        resetEstimateForNewDayIfNeeded(defaults)
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            logger.error("App Group UserDefaults is unavailable")
            return
        }
        resetEstimateForNewDayIfNeeded(defaults)
        guard let reachedSeconds = reachedUsageSeconds(
            for: event,
            activity: activity,
            defaults: defaults
        ) else { return }

        let previousSeconds = defaults.double(forKey: estimatedUsedTimeKey)
        let newestSeconds = max(previousSeconds, reachedSeconds)
        defaults.set(newestSeconds, forKey: estimatedUsedTimeKey)
        defaults.set(true, forKey: hasUsageCheckpointKey)
        defaults.set(
            Date.now.timeIntervalSince1970,
            forKey: estimateUpdatedAtKey
        )

        logger.notice(
            "Reached \(event.rawValue, privacy: .public); stored \(newestSeconds, privacy: .public) seconds"
        )
        WidgetCenter.shared.reloadTimelines(ofKind: "CountdownWidget")
    }

    private func resetEstimateForNewDayIfNeeded(_ defaults: UserDefaults) {
        let today = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        guard defaults.double(forKey: lastResetDayKey) != today else { return }

        defaults.set(today, forKey: lastResetDayKey)
        defaults.set(false, forKey: dailyLimitReachedKey)
        defaults.set(false, forKey: hasUsageCheckpointKey)
        defaults.set(0, forKey: estimatedUsedTimeKey)
        defaults.set(0, forKey: estimateUpdatedAtKey)

        logger.notice("Started a new daily monitoring interval")
        WidgetCenter.shared.reloadTimelines(ofKind: "CountdownWidget")
    }

    private func reachedUsageSeconds(
        for event: DeviceActivityEvent.Name,
        activity: DeviceActivityName,
        defaults: UserDefaults
    ) -> TimeInterval? {
        if activity == .mujoUsage {
            return usageCheckpointSeconds(from: event)
        }

        if activity == .mujoLimit {
            return currentLimitSeconds(from: event, defaults: defaults)
        }

        logger.notice(
            "Ignored event from obsolete activity: \(activity.rawValue, privacy: .public)"
        )
        return nil
    }

    private func usageCheckpointSeconds(
        from event: DeviceActivityEvent.Name
    ) -> TimeInterval? {
        let prefix = "mujo.used."
        guard event.rawValue.hasPrefix(prefix),
              let minutes = Int(event.rawValue.dropFirst(prefix.count))
        else {
            logger.error("Unknown usage event: \(event.rawValue, privacy: .public)")
            return nil
        }

        return TimeInterval(minutes * 60)
    }

    private func currentLimitSeconds(
        from event: DeviceActivityEvent.Name,
        defaults: UserDefaults
    ) -> TimeInterval? {
        let prefix = "mujo.limit."
        guard event.rawValue.hasPrefix(prefix),
              let configuredLimit = TimeInterval(
                  event.rawValue.dropFirst(prefix.count)
              ),
              configuredLimit == defaults.double(forKey: dailyLimitKey)
        else {
            logger.notice(
                "Ignored stale limit event: \(event.rawValue, privacy: .public)"
            )
            return nil
        }

        defaults.set(true, forKey: dailyLimitReachedKey)
        return configuredLimit
    }
}
