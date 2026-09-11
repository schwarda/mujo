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
    static let mujoUsage = Self(MujoShared.Monitoring.usageActivityName)
    static let mujoLimit = Self(MujoShared.Monitoring.limitActivityName)
}

private let logger = Logger(
    subsystem: "AikariStudio.Mujo",
    category: "ActivityMonitor"
)

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard let defaults = UserDefaults(
            suiteName: MujoShared.appGroupIdentifier
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
            suiteName: MujoShared.appGroupIdentifier
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
            forKey: MujoShared.DefaultsKey.estimatedUsedTime
        )
        let newestSeconds = max(previousSeconds, reachedSeconds)
        defaults.set(
            newestSeconds,
            forKey: MujoShared.DefaultsKey.estimatedUsedTime
        )
        defaults.set(
            true,
            forKey: MujoShared.DefaultsKey.hasUsageCheckpoint
        )

        logger.notice(
            "Reached \(event.rawValue, privacy: .public); stored \(newestSeconds, privacy: .public) seconds"
        )
        WidgetCenter.shared.reloadTimelines(ofKind: MujoShared.widgetKind)
    }

    private func resetEstimateForNewDayIfNeeded(_ defaults: UserDefaults) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now).timeIntervalSince1970
        let timeZoneIdentifier = calendar.timeZone.identifier
        let isCurrentDay = defaults.double(
            forKey: MujoShared.DefaultsKey.lastCheckpointResetDay
        ) == today
        let isCurrentTimeZone = defaults.string(
            forKey: MujoShared.DefaultsKey.lastCheckpointTimeZoneIdentifier
        ) == timeZoneIdentifier
        guard !isCurrentDay || !isCurrentTimeZone else { return }

        defaults.set(
            today,
            forKey: MujoShared.DefaultsKey.lastCheckpointResetDay
        )
        defaults.set(
            timeZoneIdentifier,
            forKey: MujoShared.DefaultsKey.lastCheckpointTimeZoneIdentifier
        )
        defaults.set(
            false,
            forKey: MujoShared.DefaultsKey.hasUsageCheckpoint
        )
        defaults.set(
            0,
            forKey: MujoShared.DefaultsKey.estimatedUsedTime
        )

        logger.notice("Started a new daily monitoring interval")
        WidgetCenter.shared.reloadTimelines(ofKind: MujoShared.widgetKind)
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
        let prefix = MujoShared.Monitoring.usageEventPrefix
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
        let prefix = MujoShared.Monitoring.limitEventPrefix
        guard event.rawValue.hasPrefix(prefix),
              let configuredLimit = TimeInterval(
                  event.rawValue.dropFirst(prefix.count)
              ),
              configuredLimit == defaults.double(
                  forKey: MujoShared.DefaultsKey.dailyLimit
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
