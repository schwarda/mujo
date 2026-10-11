//
//  WidgetUsageEstimateTests.swift
//  MujoTests
//
//  Created by Aikari Studio on 05/09/2026.
//

import Foundation
import Testing
@testable import Mujo

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
        #expect(estimate.remainingTime == AppConfiguration.defaultDailyLimit)
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

    @Test("A minute checkpoint is shown precisely in the final window")
    func preservesMinuteCheckpointInFinalWindow() {
        let estimate = estimate(snapshot: snapshot(
            storedDailyLimit: 2 * 60 * 60,
            estimatedUsedTime: 106 * 60,
            estimateDay: dayStart.timeIntervalSince1970,
            hasCheckpoint: true
        ))

        #expect(estimate.isAvailable)
        #expect(estimate.remainingTime == 14 * 60)
    }

    @Test("Changing the limit uses 15-minute display steps outside its final window")
    func roundsOutsideFinalWindowAfterLimitChange() {
        let usageSnapshot = snapshot(
            storedDailyLimit: 2 * 60 * 60,
            estimatedUsedTime: 113 * 60,
            estimateDay: dayStart.timeIntervalSince1970,
            hasCheckpoint: true
        )

        #expect(estimate(snapshot: usageSnapshot).remainingTime == 7 * 60)
        #expect(UsageEstimator.estimate(
            from: usageSnapshot,
            dailyLimit: 135 * 60,
            at: dayStart.addingTimeInterval(12 * 60 * 60),
            calendar: calendar
        ).remainingTime == 30 * 60)
        #expect(estimate(snapshot: usageSnapshot).remainingTime == 7 * 60)
        #expect(usageSnapshot.estimatedUsedTime == 113 * 60)

        let earlierMinuteCheckpoint = snapshot(
            storedDailyLimit: 2 * 60 * 60,
            estimatedUsedTime: 61 * 60,
            estimateDay: dayStart.timeIntervalSince1970,
            hasCheckpoint: true
        )
        #expect(estimate(snapshot: earlierMinuteCheckpoint).remainingTime == 60 * 60)
    }

    @Test("Four-hour limits use a 30-minute final window")
    func fourHourFinalWindow() {
        let outside = estimate(snapshot: snapshot(
            storedDailyLimit: 4 * 60 * 60,
            estimatedUsedTime: 209 * 60,
            estimateDay: dayStart.timeIntervalSince1970,
            hasCheckpoint: true
        ))
        let inside = estimate(snapshot: snapshot(
            storedDailyLimit: 4 * 60 * 60,
            estimatedUsedTime: 211 * 60,
            estimateDay: dayStart.timeIntervalSince1970,
            hasCheckpoint: true
        ))

        #expect(outside.remainingTime == 45 * 60)
        #expect(inside.remainingTime == 29 * 60)
    }

    @Test("Display resolution changes at the shared final-window boundary")
    func displayResolutionAtFinalWindow() {
        let resolution = AppConfiguration.DailyLimit.displayResolutionMinutes

        #expect(resolution(30 * 60, 120 * 60) == 15)
        #expect(resolution(15 * 60, 120 * 60) == 1)
        #expect(resolution(45 * 60, 240 * 60) == 15)
        #expect(resolution(30 * 60, 240 * 60) == 1)
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

    @Test("Monitoring started today begins with zero confirmed usage")
    func startsMeasurementAtSetup() {
        let estimate = estimate(snapshot: snapshot(
            estimateDay: dayStart.timeIntervalSince1970,
            monitoringStartedAt: dayStart
                .addingTimeInterval(60)
                .timeIntervalSince1970
        ))

        #expect(estimate.isAvailable)
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

    @Test("Displayed used time is the consumed part of the daily limit")
    func derivesDisplayedUsedTime() {
        let partialUsage = UsageEstimate.displayedUsedTime(
            remainingTime: 90 * 60,
            dailyLimit: 3 * 60 * 60
        )
        let exhaustedUsage = UsageEstimate.displayedUsedTime(
            remainingTime: -60,
            dailyLimit: 3 * 60 * 60
        )
        let unusedLimit = UsageEstimate.displayedUsedTime(
            remainingTime: 4 * 60 * 60,
            dailyLimit: 3 * 60 * 60
        )

        #expect(partialUsage == 90 * 60)
        #expect(exhaustedUsage == 3 * 60 * 60)
        #expect(unusedLimit == 0)
    }

    @Test("An impossible stored 12-hour value is never displayed")
    func rejectsImpossibleStoredUsage() {
        let monitoringStart = dayStart.addingTimeInterval(60)
        let estimate = UsageEstimator.estimate(
            from: snapshot(
                storedDailyLimit: 12 * 60 * 60,
                estimatedUsedTime: 12 * 60 * 60,
                estimateDay: dayStart.timeIntervalSince1970,
                monitoringStartedAt: monitoringStart.timeIntervalSince1970,
                hasCheckpoint: true
            ),
            at: monitoringStart.addingTimeInterval(5 * 60),
            calendar: calendar
        )

        #expect(!estimate.isAvailable)
        #expect(estimate.remainingTime == 12 * 60 * 60)
    }

    @Test("Travel from Bratislava to New York invalidates the estimate")
    func invalidatesEstimateAfterWestwardTravel() throws {
        try expectUnavailableAfterTravel(
            from: "Europe/Bratislava",
            to: "America/New_York"
        )
    }

    @Test("Travel between zones with the same local day keeps the estimate")
    func keepsEstimateBetweenBerlinAndBratislava() throws {
        let berlin = try makeCalendar(
            timeZoneIdentifier: "Europe/Berlin"
        )
        let bratislava = try makeCalendar(
            timeZoneIdentifier: "Europe/Bratislava"
        )
        let date = try makeUTCDate(
            year: 2026,
            month: 10,
            day: 6,
            hour: 12
        )
        let estimate = UsageEstimator.estimate(
            from: snapshot(
                estimatedUsedTime: 60 * 60,
                estimateDay: berlin.startOfDay(for: date)
                    .timeIntervalSince1970,
                monitoringStartedAt: berlin.startOfDay(for: date)
                    .addingTimeInterval(-60)
                    .timeIntervalSince1970,
                hasCheckpoint: true,
                checkpointTimeZoneIdentifier: berlin.timeZone.identifier
            ),
            at: date,
            calendar: bratislava
        )

        #expect(estimate.isAvailable)
        #expect(estimate.unavailableReason == nil)
        #expect(estimate.remainingTime == 4 * 60 * 60)
    }

    @Test("Travel from Bratislava to Tokyo invalidates the estimate")
    func invalidatesEstimateAfterEastwardTravel() throws {
        try expectUnavailableAfterTravel(
            from: "Europe/Bratislava",
            to: "Asia/Tokyo"
        )
    }

    @Test("Crossing the date line invalidates the estimate")
    func invalidatesEstimateAcrossDateLine() throws {
        try expectUnavailableAfterTravel(
            from: "Pacific/Kiritimati",
            to: "Pacific/Honolulu"
        )
    }

    @Test("A daylight-saving change keeps today's estimate valid")
    func keepsEstimateAcrossDaylightSavingChange() throws {
        let bratislava = try makeCalendar(
            timeZoneIdentifier: "Europe/Bratislava"
        )
        let date = try makeUTCDate(
            year: 2026,
            month: 10,
            day: 25,
            hour: 12
        )
        let estimate = UsageEstimator.estimate(
            from: snapshot(
                estimatedUsedTime: 60 * 60,
                estimateDay: bratislava.startOfDay(for: date)
                    .timeIntervalSince1970,
                monitoringStartedAt: bratislava.startOfDay(for: date)
                    .addingTimeInterval(-60)
                    .timeIntervalSince1970,
                hasCheckpoint: true,
                checkpointTimeZoneIdentifier: bratislava.timeZone.identifier
            ),
            at: date,
            calendar: bratislava
        )

        #expect(estimate.isAvailable)
        #expect(estimate.remainingTime == 4 * 60 * 60)
    }

    private func estimate(
        snapshot: UsageSnapshot
    ) -> UsageEstimate {
        UsageEstimator.estimate(
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
        hasCheckpoint: Bool = false,
        checkpointTimeZoneIdentifier: String? = "GMT"
    ) -> UsageSnapshot {
        UsageSnapshot(
            storedDailyLimit: storedDailyLimit,
            estimatedUsedTime: estimatedUsedTime,
            estimateDay: estimateDay,
            checkpointTimeZoneIdentifier: checkpointTimeZoneIdentifier,
            monitoringStartedAt: monitoringStartedAt,
            hasCheckpoint: hasCheckpoint
        )
    }

    private func expectUnavailableAfterTravel(
        from sourceIdentifier: String,
        to destinationIdentifier: String
    ) throws {
        let sourceCalendar = try makeCalendar(
            timeZoneIdentifier: sourceIdentifier
        )
        let destinationCalendar = try makeCalendar(
            timeZoneIdentifier: destinationIdentifier
        )
        let date = try makeUTCDate(
            year: 2026,
            month: 9,
            day: 11,
            hour: 12
        )
        let sourceDay = sourceCalendar.startOfDay(for: date)
        let estimate = UsageEstimator.estimate(
            from: snapshot(
                estimatedUsedTime: 60 * 60,
                estimateDay: sourceDay.timeIntervalSince1970,
                monitoringStartedAt: sourceDay
                    .addingTimeInterval(-60)
                    .timeIntervalSince1970,
                hasCheckpoint: true,
                checkpointTimeZoneIdentifier: sourceCalendar.timeZone.identifier
            ),
            at: date,
            calendar: destinationCalendar
        )

        #expect(!estimate.isAvailable)
        #expect(estimate.unavailableReason == .timeZoneChanged)
        #expect(estimate.remainingTime == 5 * 60 * 60)
    }

    private func makeCalendar(
        timeZoneIdentifier: String
    ) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(
            TimeZone(identifier: timeZoneIdentifier)
        )
        return calendar
    }

    private func makeUTCDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return try #require(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        )))
    }
}
