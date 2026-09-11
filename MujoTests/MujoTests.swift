//
//  MujoTests.swift
//  MujoTests
//
//  Created by Aikari Studio on 05/09/2026.
//

import Foundation
import Testing
@testable import Mujo

@Suite("Time formatting")
struct TimeFormattingTests {
    @Test("Zero and negative durations use the empty-time symbol")
    func formatsEmptyTime() {
        #expect(TimeInterval(0).formatted() == "Ø")
        #expect(TimeInterval(59).formatted() == "Ø")
        #expect(TimeInterval(-60).formatted() == "Ø")
    }

    @Test("Durations are truncated to whole minutes")
    func formatsHoursAndMinutes() {
        #expect(TimeInterval(60).formatted() == "0:01")
        #expect(TimeInterval(3_599).formatted() == "0:59")
        #expect(TimeInterval(3_600).formatted() == "1:00")
        #expect(TimeInterval(13_379).formatted() == "3:42")
    }
}

@Suite("Shared monitoring identifiers")
struct MonitoringIdentifierTests {
    @Test("Usage events include their checkpoint in minutes")
    func createsUsageEventNames() {
        #expect(
            MujoShared.Monitoring.usageEventName(minutes: 15)
                == "mujo.usage.15"
        )
        #expect(
            MujoShared.Monitoring.usageEventName(minutes: 12 * 60)
                == "mujo.usage.720"
        )
    }

    @Test("Limit events include their threshold in seconds")
    func createsLimitEventNames() {
        #expect(
            MujoShared.Monitoring.limitEventName(seconds: 5 * 60 * 60)
                == "mujo.limit.18000"
        )
    }
}

@Suite("Widget usage estimate")
struct WidgetUsageEstimateTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
    private let dayStart = Date(timeIntervalSince1970: 86_400_000)

    @Test("No monitoring data produces an unavailable estimate")
    func unavailableWithoutMonitoringData() {
        let estimate = estimate(
            snapshot: snapshot(storedDailyLimit: 0)
        )

        #expect(!estimate.isAvailable)
        #expect(estimate.remainingTime == MujoShared.defaultDailyLimit)
    }

    @Test("A checkpoint from today reduces the remaining time")
    func usesTodaysCheckpoint() {
        let estimate = estimate(snapshot: snapshot(
            estimatedUsedTime: 75 * 60,
            estimateDay: dayStart.timeIntervalSince1970,
            monitoringStartedAt: dayStart
                .addingTimeInterval(60)
                .timeIntervalSince1970,
            hasCheckpoint: true
        ))

        #expect(estimate.isAvailable)
        #expect(estimate.remainingTime == 3 * 60 * 60 + 45 * 60)
    }

    @Test("An old estimate is reset when monitoring predates today")
    func resetsEstimateAtMidnight() {
        let estimate = estimate(snapshot: snapshot(
            estimatedUsedTime: 2 * 60 * 60,
            estimateDay: dayStart
                .addingTimeInterval(-86_400)
                .timeIntervalSince1970,
            monitoringStartedAt: dayStart
                .addingTimeInterval(-86_400)
                .timeIntervalSince1970,
            hasCheckpoint: true
        ))

        #expect(estimate.isAvailable)
        #expect(estimate.remainingTime == 5 * 60 * 60)
    }

    @Test("Monitoring started today cannot establish earlier usage")
    func unavailableWhenMonitoringStartedToday() {
        let estimate = estimate(snapshot: snapshot(
            monitoringStartedAt: dayStart
                .addingTimeInterval(60)
                .timeIntervalSince1970
        ))

        #expect(!estimate.isAvailable)
        #expect(estimate.remainingTime == 5 * 60 * 60)
    }

    @Test("Remaining time never becomes negative")
    func clampsRemainingTimeToZero() {
        let estimate = estimate(snapshot: snapshot(
            estimatedUsedTime: 6 * 60 * 60,
            estimateDay: dayStart.timeIntervalSince1970,
            hasCheckpoint: true
        ))

        #expect(estimate.isAvailable)
        #expect(estimate.remainingTime == 0)
    }

    private func estimate(
        snapshot: WidgetUsageSnapshot
    ) -> WidgetUsageEstimate {
        WidgetUsageEstimator.estimate(
            from: snapshot,
            at: dayStart.addingTimeInterval(12 * 60 * 60),
            calendar: calendar
        )
    }

    private func snapshot(
        storedDailyLimit: TimeInterval = 5 * 60 * 60,
        estimatedUsedTime: TimeInterval = 0,
        estimateDay: TimeInterval = 0,
        monitoringStartedAt: TimeInterval = 0,
        hasCheckpoint: Bool = false
    ) -> WidgetUsageSnapshot {
        WidgetUsageSnapshot(
            storedDailyLimit: storedDailyLimit,
            estimatedUsedTime: estimatedUsedTime,
            estimateDay: estimateDay,
            monitoringStartedAt: monitoringStartedAt,
            hasCheckpoint: hasCheckpoint
        )
    }
}
