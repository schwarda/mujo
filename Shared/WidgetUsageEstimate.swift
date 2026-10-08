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
    nonisolated enum UnavailableReason: Equatable, Sendable {
        case missingData
        case timeZoneChanged
    }

    let remainingTime: TimeInterval
    let isAvailable: Bool
    let unavailableReason: UnavailableReason?

    init(
        remainingTime: TimeInterval,
        isAvailable: Bool,
        unavailableReason: UnavailableReason? = nil
    ) {
        self.remainingTime = remainingTime
        self.isAvailable = isAvailable
        self.unavailableReason = unavailableReason
    }
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
        guard let checkpointTimeZoneIdentifier = snapshot
            .checkpointTimeZoneIdentifier,
              let checkpointTimeZone = TimeZone(
                identifier: checkpointTimeZoneIdentifier
              )
        else {
            return UsageEstimate(
                remainingTime: dailyLimit,
                isAvailable: false,
                unavailableReason: .missingData
            )
        }

        let today = calendar.startOfDay(for: date).timeIntervalSince1970
        var checkpointCalendar = calendar
        checkpointCalendar.timeZone = checkpointTimeZone
        let checkpointTimeZoneDay = checkpointCalendar
            .startOfDay(for: date)
            .timeIntervalSince1970
        guard checkpointTimeZoneDay == today,
              localDateComponents(
                for: date,
                calendar: checkpointCalendar
              ) == localDateComponents(for: date, calendar: calendar)
        else {
            return UsageEstimate(
                remainingTime: dailyLimit,
                isAvailable: false,
                unavailableReason: .timeZoneChanged
            )
        }

        let monitoringPredatesToday = snapshot.monitoringStartedAt > 0
            && snapshot.monitoringStartedAt <= today
        let estimateWasResetToday = snapshot.estimateDay == today
        let monitoringStartedToday = snapshot.monitoringStartedAt >= today
            && snapshot.monitoringStartedAt <= date.timeIntervalSince1970
        let canUseStoredEstimate = estimateWasResetToday
            && (
                snapshot.hasCheckpoint
                    || monitoringPredatesToday
                    || monitoringStartedToday
            )
        let canAssumeZeroUsage = !estimateWasResetToday
            && monitoringPredatesToday

        guard canUseStoredEstimate || canAssumeZeroUsage else {
            return UsageEstimate(
                remainingTime: dailyLimit,
                isAvailable: false,
                unavailableReason: .missingData
            )
        }

        let confirmedUsedTime = canUseStoredEstimate
            ? AppConfiguration.DailyLimit.normalizedUsage(
                snapshot.estimatedUsedTime
            )
            : 0
        if confirmedUsedTime > 0,
           UsageCheckpointValidator.decision(
               reachedSeconds: confirmedUsedTime,
               monitoringStartedAt: snapshot.monitoringStartedAt,
               now: date,
               calendar: calendar
           ) != .accept {
            return UsageEstimate(
                remainingTime: dailyLimit,
                isAvailable: false,
                unavailableReason: .missingData
            )
        }
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
            isAvailable: true,
            unavailableReason: nil
        )
    }

    private static func localDateComponents(
        for date: Date,
        calendar: Calendar
    ) -> DateComponents {
        calendar.dateComponents([.era, .year, .month, .day], from: date)
    }
}

// Compatibility names for the existing tests while the shared model is adopted.
typealias WidgetUsageSnapshot = UsageSnapshot
typealias WidgetUsageEstimate = UsageEstimate
typealias WidgetUsageEstimator = UsageEstimator
