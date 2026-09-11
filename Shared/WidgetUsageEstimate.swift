//
//  WidgetUsageEstimate.swift
//  Mujo
//

import Foundation

struct WidgetUsageSnapshot {
    let storedDailyLimit: TimeInterval
    let estimatedUsedTime: TimeInterval
    let estimateDay: TimeInterval
    let checkpointTimeZoneIdentifier: String?
    let monitoringStartedAt: TimeInterval
    let hasCheckpoint: Bool
}

struct WidgetUsageEstimate {
    let remainingTime: TimeInterval
    let isAvailable: Bool
}

enum WidgetUsageEstimator {
    static func estimate(
        from snapshot: WidgetUsageSnapshot,
        at date: Date,
        calendar: Calendar = .current
    ) -> WidgetUsageEstimate {
        let dailyLimit = snapshot.storedDailyLimit > 0
            ? snapshot.storedDailyLimit
            : MujoShared.defaultDailyLimit
        guard snapshot.checkpointTimeZoneIdentifier
            == calendar.timeZone.identifier else {
            return WidgetUsageEstimate(
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
            return WidgetUsageEstimate(
                remainingTime: dailyLimit,
                isAvailable: false
            )
        }

        let usedTime = canUseStoredEstimate
            ? snapshot.estimatedUsedTime
            : 0

        return WidgetUsageEstimate(
            remainingTime: max(0, dailyLimit - usedTime),
            isAvailable: true
        )
    }
}
