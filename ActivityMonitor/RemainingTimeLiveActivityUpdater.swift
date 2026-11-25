//
//  RemainingTimeLiveActivityUpdater.swift
//  ActivityMonitor
//

import ActivityKit
import Foundation

enum RemainingTimeLiveActivityUpdater {
    static func refresh(defaults: UserDefaults, activeScope: String) {
        guard AppConfiguration.Features.liveActivitiesEnabled else {
            return
        }
        // ActivityKit documents app/APNs updates. Extension-side updates are
        // best-effort and depend on the system keeping this process alive.
        Task {
            await applyLatestEstimate(from: defaults, activeScope: activeScope)
        }
    }

    static func endAll(defaults: UserDefaults, activeScope: String) {
        Task {
            for activity in Activity<RemainingTimeActivityAttributes>.activities
            where activity.activityState == .active || activity.activityState == .stale {
                guard scopeIsCurrent(activeScope, defaults: defaults) else { return }
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private static func applyLatestEstimate(
        from defaults: UserDefaults,
        activeScope: String
    ) async {
        guard scopeIsCurrent(activeScope, defaults: defaults),
              let storedLimit = defaults.object(
            forKey: AppConfiguration.DefaultsKey.dailyLimit
        ) as? TimeInterval,
              storedLimit.isFinite,
              storedLimit > 0
        else { return }

        let calendar = Calendar.current
        guard defaults.double(
            forKey: AppConfiguration.DefaultsKey.lastCheckpointResetDay
        ) == calendar.startOfDay(for: .now).timeIntervalSince1970
        else { return }

        let limitMinutes = Int(
            AppConfiguration.DailyLimit.normalizedLimit(storedLimit) / 60
        )
        let usedSeconds = AppConfiguration.DailyLimit.normalizedUsage(
            defaults.double(forKey: AppConfiguration.DefaultsKey.estimatedUsedTime)
        )
        let remainingMinutes = max(0, limitMinutes - Int(usedSeconds / 60))
        let finalWindow = AppConfiguration.DailyLimit.liveActivityWindowMinutes(
            forLimitMinutes: limitMinutes
        )

        let activities = Activity<RemainingTimeActivityAttributes>.activities
            .filter {
                $0.activityState == .active || $0.activityState == .stale
            }
        for activity in activities {
            guard scopeIsCurrent(activeScope, defaults: defaults) else { return }
            if remainingMinutes == 0
                || remainingMinutes > finalWindow
                || activity.attributes.limitMinutes != limitMinutes {
                await activity.end(nil, dismissalPolicy: .immediate)
                continue
            }

            let now = Date.now
            let state = RemainingTimeActivityAttributes.ContentState(
                remainingMinutes: remainingMinutes,
                updatedAt: now
            )
            await activity.update(ActivityContent(
                state: state,
                staleDate: now.addingTimeInterval(2 * 60)
            ))
        }

        // If callbacks arrived close together, another task may have applied
        // an older value last. Read the shared high-water mark again.
        if defaults.double(
            forKey: AppConfiguration.DefaultsKey.estimatedUsedTime
        ) > usedSeconds {
            await applyLatestEstimate(from: defaults, activeScope: activeScope)
        }
    }

    private static func scopeIsCurrent(_ activeScope: String, defaults: UserDefaults) -> Bool {
        (try? UsageScopeLock.withLock {
            AppConfiguration.Monitoring.activeUsageActivityName(in: defaults) == activeScope
        }) == true
    }
}
