//
//  WidgetUsageEstimate.swift
//  Mujo
//

import Foundation

struct UsageSnapshot: Equatable {
    let storedDailyLimit: TimeInterval
    let estimatedUsedTime: TimeInterval
    let estimateDay: TimeInterval
    let checkpointTimeZoneIdentifier: String?
    let monitoringStartedAt: TimeInterval
    let hasCheckpoint: Bool
}

struct UsageEstimate: Equatable {
    let remainingTime: TimeInterval
    let isAvailable: Bool
}

enum UsageEstimator {
    static func estimate(
        from snapshot: UsageSnapshot,
        dailyLimit overrideLimit: TimeInterval? = nil,
        at date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> UsageEstimate {
        let storedLimit = snapshot.storedDailyLimit > 0
            ? snapshot.storedDailyLimit
            : AppConfiguration.defaultDailyLimit
        let dailyLimit = AppConfiguration.DailyLimit.normalizedLimit(
            overrideLimit ?? storedLimit
        )
        guard snapshot.checkpointTimeZoneIdentifier
            == calendar.timeZone.identifier else {
            return UsageEstimate(
                remainingTime: dailyLimit,
                isAvailable: false
            )
        }

        let today = calendar.startOfDay(for: date).timeIntervalSince1970
        let monitoringPredatesToday = snapshot.monitoringStartedAt > 0
            && snapshot.monitoringStartedAt <= today
        let estimateWasResetToday = snapshot.estimateDay == today
        let canUseStoredEstimate = estimateWasResetToday
            && (snapshot.hasCheckpoint || monitoringPredatesToday)
        let canAssumeZeroUsage = !estimateWasResetToday
            && monitoringPredatesToday

        guard canUseStoredEstimate || canAssumeZeroUsage else {
            return UsageEstimate(
                remainingTime: dailyLimit,
                isAvailable: false
            )
        }

        let confirmedUsedTime = canUseStoredEstimate
            ? AppConfiguration.DailyLimit.normalizedUsage(
                snapshot.estimatedUsedTime
            )
            : 0
        let confirmedRemaining = max(0, dailyLimit - confirmedUsedTime)
        let displayResolutionMinutes = AppConfiguration.DailyLimit
            .displayResolutionMinutes(
                remainingTime: confirmedRemaining,
                dailyLimit: dailyLimit
            )
        let coarseInterval = TimeInterval(
            AppConfiguration.DailyLimit.stepMinutes * 60
        )

        // A minute checkpoint from an earlier limit remains stored, but it
        // affects the display only inside the current limit's final window.
        let displayedUsedTime = displayResolutionMinutes == 1
            ? confirmedUsedTime
            : floor(confirmedUsedTime / coarseInterval) * coarseInterval

        return UsageEstimate(
            remainingTime: max(0, dailyLimit - displayedUsedTime),
            isAvailable: true
        )
    }
}

// Compatibility names for the existing tests while the shared model is adopted.
typealias WidgetUsageSnapshot = UsageSnapshot
typealias WidgetUsageEstimate = UsageEstimate
typealias WidgetUsageEstimator = UsageEstimator
