import Foundation
import Testing
@testable import Mujo

@Suite("Remaining-time badge")
struct RemainingTimeBadgeTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
    private let dayStart = Date(timeIntervalSince1970: 86_400_000)

    @Test("Badge stays hidden until a limit and estimate are available")
    func unavailableEstimate() {
        #expect(RemainingTimeBadge.badgeCount(
            from: snapshot(storedDailyLimit: 0)
        ) == nil)
        #expect(RemainingTimeBadge.badgeCount(
            from: snapshot(storedDailyLimit: 120 * 60)
        ) == nil)
    }

    @Test("Badge uses the same coarse value as widgets")
    func coarseValue() {
        let value = RemainingTimeBadge.badgeCount(
            from: snapshot(
                storedDailyLimit: 120 * 60,
                estimatedUsedTime: 31 * 60,
                estimateDay: dayStart.timeIntervalSince1970,
                hasCheckpoint: true
            ),
            at: dayStart.addingTimeInterval(12 * 60 * 60),
            calendar: calendar
        )

        #expect(value == 90)
    }

    @Test("Badge disappears when no time remains")
    func exhaustedLimit() {
        let value = RemainingTimeBadge.badgeCount(
            from: snapshot(
                storedDailyLimit: 120 * 60,
                estimatedUsedTime: 120 * 60,
                estimateDay: dayStart.timeIntervalSince1970,
                hasCheckpoint: true
            ),
            at: dayStart.addingTimeInterval(12 * 60 * 60),
            calendar: calendar
        )

        #expect(value == 0)
    }

    private func snapshot(
        storedDailyLimit: TimeInterval,
        estimatedUsedTime: TimeInterval = 0,
        estimateDay: TimeInterval = 0,
        hasCheckpoint: Bool = false
    ) -> UsageSnapshot {
        UsageSnapshot(
            storedDailyLimit: storedDailyLimit,
            estimatedUsedTime: estimatedUsedTime,
            estimateDay: estimateDay,
            checkpointTimeZoneIdentifier: calendar.timeZone.identifier,
            monitoringStartedAt: dayStart.addingTimeInterval(60)
                .timeIntervalSince1970,
            hasCheckpoint: hasCheckpoint
        )
    }
}
