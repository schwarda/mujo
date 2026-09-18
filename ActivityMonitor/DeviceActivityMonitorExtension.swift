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
}

private let logger = Logger(
    subsystem: "AikariStudio.Mujo",
    category: "ActivityMonitor"
)

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard activity == .mujoUsage else {
            return
        }

        guard let defaults = UserDefaults(
            suiteName: AppConfiguration.appGroupIdentifier
        ) else {
            logger.error("App Group UserDefaults is unavailable")
            return
        }

        if resetEstimateForNewDayIfNeeded(defaults) {
            RemainingTimeLiveActivityUpdater.endAll()
        }
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        
        guard activity == .mujoUsage else {
            return
        }

        guard let defaults = UserDefaults(
            suiteName: AppConfiguration.appGroupIdentifier
        ) else {
            logger.error("App Group UserDefaults is unavailable")
            return
        }
        if resetEstimateForNewDayIfNeeded(defaults) {
            RemainingTimeLiveActivityUpdater.endAll()
        }
        guard let reachedSeconds = usageCheckpointSeconds(
            from: event,
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
        guard newestSeconds > previousSeconds || !defaults.bool(
            forKey: AppConfiguration.DefaultsKey.hasUsageCheckpoint
        ) else { return }

        defaults.set(newestSeconds, forKey: AppConfiguration.DefaultsKey.estimatedUsedTime)
        defaults.set(true, forKey: AppConfiguration.DefaultsKey.hasUsageCheckpoint)

        logger.notice(
            "Reached \(event.rawValue, privacy: .public); stored threshold \(newestSeconds, privacy: .public) seconds"
        )
        WidgetCenter.shared.reloadAllTimelines()

        RemainingTimeLiveActivityUpdater.refresh(defaults: defaults)

        if newestSeconds > previousSeconds {
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
    
    @discardableResult
    private func resetEstimateForNewDayIfNeeded(_ defaults: UserDefaults) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now).timeIntervalSince1970
        let timeZoneIdentifier = calendar.timeZone.identifier
        let isCurrentDay = defaults.double(
            forKey: AppConfiguration.DefaultsKey.lastCheckpointResetDay
        ) == today
        let isCurrentTimeZone = defaults.string(
            forKey: AppConfiguration.DefaultsKey.lastCheckpointTimeZoneIdentifier
        ) == timeZoneIdentifier
        guard !isCurrentDay || !isCurrentTimeZone else { return false }

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
        WidgetCenter.shared.reloadAllTimelines()
        return true
    }

    private func usageCheckpointSeconds(
        from event: DeviceActivityEvent.Name,
        defaults: UserDefaults
    ) -> TimeInterval? {
        guard let seconds = AppConfiguration.Monitoring.usageCheckpointSeconds(
            from: event.rawValue
        ),
              let storedLimit = defaults.object(
                  forKey: AppConfiguration.DefaultsKey.dailyLimit
              ) as? TimeInterval,
              storedLimit.isFinite,
              storedLimit > 0
        else {
            logger.error("Unknown usage event: \(event.rawValue, privacy: .public)")
            return nil
        }

        let limitMinutes = Int(
            AppConfiguration.DailyLimit.normalizedLimit(storedLimit) / 60
        )
        let reachedMinutes = Int(seconds / 60)
        guard AppConfiguration.Monitoring
            .usageThresholdMinutes(forLimitMinutes: limitMinutes)
            .contains(reachedMinutes) else {
            logger.notice(
                "Ignored usage event outside current plan: \(event.rawValue, privacy: .public)"
            )
            return nil
        }

        return seconds
    }
}
