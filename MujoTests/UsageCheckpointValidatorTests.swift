import Foundation
import Testing
@testable import Mujo

@Suite("Usage checkpoint validation")
struct UsageCheckpointValidatorTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private let dayStart = Date(timeIntervalSince1970: 86_400_000)

    @Test("A 12-hour callback five minutes after setup is rejected")
    func rejectsImpossibleTwelveHourCallback() {
        let startedAt = dayStart.addingTimeInterval(60)
        let now = startedAt.addingTimeInterval(5 * 60)

        #expect(UsageCheckpointValidator.decision(
            reachedSeconds: 12 * 60 * 60,
            monitoringStartedAt: startedAt.timeIntervalSince1970,
            now: now,
            calendar: calendar
        ) == .reject(.exceedsElapsedMeasurementTime))
    }

    @Test("A valid checkpoint after setup is accepted")
    func acceptsPlausibleCheckpoint() {
        let startedAt = dayStart.addingTimeInterval(60)
        let now = startedAt.addingTimeInterval(20 * 60)

        #expect(UsageCheckpointValidator.decision(
            reachedSeconds: 15 * 60,
            monitoringStartedAt: startedAt.timeIntervalSince1970,
            now: now,
            calendar: calendar
        ) == .accept)
    }

    @Test("A future measurement start rejects callbacks")
    func rejectsCallbackBeforeMeasurementStart() {
        #expect(UsageCheckpointValidator.decision(
            reachedSeconds: 60,
            monitoringStartedAt: dayStart
                .addingTimeInterval(60 * 60)
                .timeIntervalSince1970,
            now: dayStart,
            calendar: calendar,
            tolerance: 0
        ) == .reject(.beforeMeasurementStart))
    }

    @Test("A new day validates against elapsed time since midnight")
    func validatesSubsequentDayFromMidnight() {
        let nextDay = dayStart.addingTimeInterval(24 * 60 * 60)
        let now = nextDay.addingTimeInterval(30 * 60)

        #expect(UsageCheckpointValidator.decision(
            reachedSeconds: 15 * 60,
            monitoringStartedAt: dayStart.timeIntervalSince1970,
            now: now,
            calendar: calendar
        ) == .accept)
        #expect(UsageCheckpointValidator.decision(
            reachedSeconds: 60 * 60,
            monitoringStartedAt: dayStart.timeIntervalSince1970,
            now: now,
            calendar: calendar,
            tolerance: 0
        ) == .reject(.exceedsElapsedMeasurementTime))
    }
}
