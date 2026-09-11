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
    static let mujoUsage = Self(AppConfiguration.Monitoring.usageActivityName)
    static let mujoLimit = Self(AppConfiguration.Monitoring.limitActivityName)
}

private let logger = Logger(
    subsystem: "AikariStudio.Mujo",
    category: "ActivityMonitor"
)

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard let defaults = UserDefaults(
            suiteName: AppConfiguration.appGroupIdentifier
        ) else {
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

        guard let defaults = UserDefaults(
            suiteName: AppConfiguration.appGroupIdentifier
        ) else {
            logger.error("App Group UserDefaults is unavailable")
            return
        }
        resetEstimateForNewDayIfNeeded(defaults)
        guard let reachedSeconds = reachedUsageSeconds(
            for: event,
            activity: activity,
            defaults: defaults
        ) else { return }

        let previousSeconds = defaults.double(
            forKey: AppConfiguration.DefaultsKey.estimatedUsedTime
        )
        let newestSeconds = max(previousSeconds, reachedSeconds)
        defaults.set(
            newestSeconds,
            forKey: AppConfiguration.DefaultsKey.estimatedUsedTime
        )
        defaults.set(
            true,
            forKey: AppConfiguration.DefaultsKey.hasUsageCheckpoint
        )

        logger.notice(
            "Reached \(event.rawValue, privacy: .public); stored \(newestSeconds, privacy: .public) seconds"
        )
        WidgetCenter.shared.reloadTimelines(ofKind: AppConfiguration.widgetKind)
    }

    private func resetEstimateForNewDayIfNeeded(_ defaults: UserDefaults) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now).timeIntervalSince1970
        let timeZoneIdentifier = calendar.timeZone.identifier
        let isCurrentDay = defaults.double(
            forKey: AppConfiguration.DefaultsKey.lastCheckpointResetDay
        ) == today
        let isCurrentTimeZone = defaults.string(
            forKey: AppConfiguration.DefaultsKey.lastCheckpointTimeZoneIdentifier
        ) == timeZoneIdentifier
        guard !isCurrentDay || !isCurrentTimeZone else { return }

        defaults.set(
            today,
            forKey: AppConfiguration.DefaultsKey.lastCheckpointResetDay
        )
        defaults.set(
            timeZoneIdentifier,
            forKey: AppConfiguration.DefaultsKey.lastCheckpointTimeZoneIdentifier
        )
        defaults.set(
            false,
            forKey: AppConfiguration.DefaultsKey.hasUsageCheckpoint
        )
        defaults.set(
            0,
            forKey: AppConfiguration.DefaultsKey.estimatedUsedTime
        )

        logger.notice("Started a new daily monitoring interval")
        WidgetCenter.shared.reloadTimelines(ofKind: AppConfiguration.widgetKind)
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
        guard let seconds = AppConfiguration.Monitoring.usageCheckpointSeconds(
            from: event.rawValue
        ) else {
            logger.error("Unknown usage event: \(event.rawValue, privacy: .public)")
            return nil
        }

        return seconds
    }

    private func currentLimitSeconds(
        from event: DeviceActivityEvent.Name,
        defaults: UserDefaults
    ) -> TimeInterval? {
        guard let configuredLimit = AppConfiguration.Monitoring.limitSeconds(
            from: event.rawValue
        ),
              configuredLimit == defaults.double(
                  forKey: AppConfiguration.DefaultsKey.dailyLimit
              )
        else {
            logger.notice(
                "Ignored stale limit event: \(event.rawValue, privacy: .public)"
            )
            return nil
        }

        return configuredLimit
    }
}
