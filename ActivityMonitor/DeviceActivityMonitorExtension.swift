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
    static let mujoNotifications = Self(AppConfiguration.Monitoring.notificationActivityName)
}

private let logger = Logger(
    subsystem: "AikariStudio.Mujo",
    category: "ActivityMonitor"
)

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard activity == .mujoUsage || activity == .mujoLimit else {
            return
        }

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
        
        if activity == .mujoNotifications {
            handleNotificationEvent(event)
            return
        }
        
        guard activity == .mujoUsage || activity == .mujoLimit else {
            return
        }

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

        let previousSeconds = AppConfiguration.DailyLimit.normalizedUsage(
            defaults.double(
                forKey: AppConfiguration.DefaultsKey.estimatedUsedTime
            )
        )
        let newestSeconds = max(
            previousSeconds,
            AppConfiguration.DailyLimit.normalizedUsage(reachedSeconds)
        )
        defaults.set(
            newestSeconds,
            forKey: AppConfiguration.DefaultsKey.estimatedUsedTime
        )
        defaults.set(
            true,
            forKey: AppConfiguration.DefaultsKey.hasUsageCheckpoint
        )

        logger.notice(
            "Reached \(event.rawValue, privacy: .public); stored 15-minute threshold \(newestSeconds, privacy: .public) seconds"
        )
        WidgetCenter.shared.reloadTimelines(ofKind: AppConfiguration.widgetKind)
        
        if activity == .mujoUsage && newestSeconds > previousSeconds {
            handleUsageNotificationCheckpoint(
                reachedSeconds: reachedSeconds,
                defaults: defaults
            )
        }
    }
    
    private func handleUsageNotificationCheckpoint(
        reachedSeconds: TimeInterval,
        defaults: UserDefaults
    ) {
        guard let storedLimit = defaults.object(
            forKey: AppConfiguration.DefaultsKey.dailyLimit
        ) as? TimeInterval,
              storedLimit.isFinite,
              storedLimit > 0
        else { return }

        let limitMinutes = Int(
            AppConfiguration.DailyLimit.normalizedLimit(storedLimit) / 60
        )
        let reachedMinutes = Int(reachedSeconds / 60)

        guard let milestone = NotificationMilestone
            .forLimit(minutes: limitMinutes)
            .first(where: { $0.usedMinutes == reachedMinutes })
        else { return }

        NotificationDelivery.send(
            milestone,
            limitMinutes: limitMinutes,
            defaults: defaults
        )
    }
    
    private func handleNotificationEvent(_ event: DeviceActivityEvent.Name) {
        guard let defaults = UserDefaults(
            suiteName: AppConfiguration.appGroupIdentifier
        ),
              let storedLimit = defaults.object(
                  forKey: AppConfiguration.DefaultsKey.dailyLimit
              ) as? TimeInterval,
              storedLimit.isFinite,
              storedLimit > 0
        else {
            logger.error("Cannot validate notification event: daily limit unavailable")
            return
        }

        let limitMinutes = Int(
            AppConfiguration.DailyLimit.normalizedLimit(storedLimit) / 60
        )

        guard let milestone = NotificationMilestone
            .forLimit(minutes: limitMinutes)
            .first(where: {
                $0.eventName(forLimitMinutes: limitMinutes) == event.rawValue
            })
        else {
            logger.notice(
                "Ignored notification event for an outdated limit: \(event.rawValue, privacy: .public)"
            )
            return
        }
        
        let calendar = Calendar.current
        let checkpointIsFromToday =
            defaults.double(
                forKey: AppConfiguration.DefaultsKey.lastCheckpointResetDay
            ) == calendar.startOfDay(for: .now).timeIntervalSince1970
            && defaults.string(
                forKey: AppConfiguration.DefaultsKey.lastCheckpointTimeZoneIdentifier
            ) == calendar.timeZone.identifier

        let knownUsage = AppConfiguration.DailyLimit.normalizedUsage(
            defaults.double(forKey: AppConfiguration.DefaultsKey.estimatedUsedTime)
        )

        guard !(checkpointIsFromToday
                && defaults.bool(forKey: AppConfiguration.DefaultsKey.hasUsageCheckpoint)
                && knownUsage >= TimeInterval(limitMinutes * 60)) else {
            logger.notice("Skipped invitation: daily limit already reached")
            return
        }

        NotificationDelivery.send(
            milestone,
            limitMinutes: limitMinutes,
            defaults: defaults
        )
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

        return AppConfiguration.DailyLimit.normalizedUsage(seconds)
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
