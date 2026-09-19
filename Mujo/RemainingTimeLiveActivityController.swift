//
//  RemainingTimeLiveActivityController.swift
//  Mujo
//
//  Created by Aikari Studio on 16/09/2026.
//

import ActivityKit
import Foundation

@MainActor
enum RemainingTimeLiveActivityController {
    private static let startedDayKey = "mujo.liveActivity.startedDay"

    @discardableResult
    static func start(
        remainingMinutes: Int,
        limitMinutes: Int,
        updatedAt: Date
    ) async throws -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return false
        }

        let limit = AppConfiguration.DailyLimit.normalizedMinutes(limitMinutes)
        let safeRemaining = min(max(0, remainingMinutes), limit)
        let window = AppConfiguration.DailyLimit.liveActivityWindowMinutes(
            forLimitMinutes: limit
        )
        guard (1...window).contains(safeRemaining) else { return false }
        let content = content(
            remainingMinutes: safeRemaining,
            updatedAt: updatedAt
        )

        if let existing = runningActivities.first {
            if existing.attributes.limitMinutes == limit {
                await existing.update(content)
                rememberStartedToday()
                return true
            }

            await existing.end(nil, dismissalPolicy: .immediate)
        }

        _ = try Activity<RemainingTimeActivityAttributes>.request(
            attributes: RemainingTimeActivityAttributes(limitMinutes: limit),
            content: content,
            pushType: nil
        )
        rememberStartedToday()
        return true
    }

    static func reconcile(
        with snapshot: UsageSnapshot,
        resumeAfterLimitChange: Bool = false
    ) async {
        let activities = runningActivities
        if activities.contains(where: {
            Calendar.current.isDate($0.content.state.updatedAt, inSameDayAs: .now)
        }) {
            rememberStartedToday()
        }
        guard !activities.isEmpty
            || (resumeAfterLimitChange && wasStartedToday) else { return }

        let estimate = UsageEstimator.estimate(from: snapshot, at: .now)
        let limit = Int(
            AppConfiguration.DailyLimit.normalizedLimit(
                snapshot.storedDailyLimit
            ) / 60
        )
        let remaining = Int(estimate.remainingTime / 60)
        let window = AppConfiguration.DailyLimit.liveActivityWindowMinutes(
            forLimitMinutes: limit
        )

        guard estimate.isAvailable, (1...window).contains(remaining) else {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        if let current = activities.first(where: {
            $0.attributes.limitMinutes == limit
        }) {
            await current.update(content(
                remainingMinutes: remaining,
                updatedAt: .now
            ))
            for activity in activities where activity.id != current.id {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        // The old attributes cannot be reused after a limit change.
        // Do not turn yesterday's activity into a new invitation today.
        guard wasStartedToday else { return }
        _ = try? await start(
            remainingMinutes: remaining,
            limitMinutes: limit,
            updatedAt: .now
        )
    }

    static func restartActiveAfterAppUpdate(
        with snapshot: UsageSnapshot
    ) async throws {
        let activities = runningActivities
        guard !activities.isEmpty else { return }

        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        let estimate = UsageEstimator.estimate(from: snapshot, at: .now)
        let limit = Int(
            AppConfiguration.DailyLimit.normalizedLimit(
                snapshot.storedDailyLimit
            ) / 60
        )
        let remaining = Int(estimate.remainingTime / 60)
        let window = AppConfiguration.DailyLimit.liveActivityWindowMinutes(
            forLimitMinutes: limit
        )

        guard estimate.isAvailable,
              (1...window).contains(remaining)
        else { return }

        _ = try await start(
            remainingMinutes: remaining,
            limitMinutes: limit,
            updatedAt: .now
        )
    }

    private static var wasStartedToday: Bool {
        let today = Calendar.current.startOfDay(for: .now)
        return UserDefaults.standard.object(forKey: startedDayKey) as? Date
            == today
    }

    private static func rememberStartedToday() {
        UserDefaults.standard.set(
            Calendar.current.startOfDay(for: .now),
            forKey: startedDayKey
        )
    }

    private static var runningActivities: [Activity<RemainingTimeActivityAttributes>] {
        Activity<RemainingTimeActivityAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
    }

    private static func content(
        remainingMinutes: Int,
        updatedAt: Date
    ) -> ActivityContent<RemainingTimeActivityAttributes.ContentState> {
        let state = RemainingTimeActivityAttributes.ContentState(
            remainingMinutes: remainingMinutes,
            updatedAt: updatedAt
        )
        return ActivityContent(
            state: state,
            staleDate: updatedAt.addingTimeInterval(2 * 60)
        )
    }
}
