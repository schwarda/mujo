//
//  LocalDayIntervalTests.swift
//  MujoTests
//

import Foundation
import Testing
@testable import Mujo

@Suite("Local day interval")
struct LocalDayIntervalTests {
    @Test("Crossing midnight selects the next local day")
    func changesAtMidnight() throws {
        let calendar = try makeCalendar(timeZone: "Europe/Bratislava")
        let beforeMidnight = try makeDate(
            year: 2026,
            month: 9,
            day: 11,
            hour: 23,
            minute: 59,
            second: 59,
            calendar: calendar
        )
        let afterMidnight = beforeMidnight.addingTimeInterval(2)

        let firstDay = LocalDayInterval.containing(
            beforeMidnight,
            calendar: calendar
        )
        let secondDay = LocalDayInterval.containing(
            afterMidnight,
            calendar: calendar
        )

        #expect(firstDay.end == secondDay.start)
        #expect(firstDay != secondDay)
    }

    @Test("A regular local day lasts 24 hours")
    func createsRegularDay() throws {
        let calendar = try makeCalendar(timeZone: "Europe/Bratislava")
        let date = try makeDate(
            year: 2026,
            month: 9,
            day: 11,
            hour: 12,
            calendar: calendar
        )

        let interval = LocalDayInterval.containing(date, calendar: calendar)

        #expect(interval.duration == 24 * 60 * 60)
        #expect(calendar.component(.hour, from: interval.start) == 0)
        #expect(calendar.component(.hour, from: interval.end) == 0)
    }

    @Test("The spring daylight-saving day lasts 23 hours")
    func handlesSpringDaylightSavingChange() throws {
        let calendar = try makeCalendar(timeZone: "Europe/Bratislava")
        let date = try makeDate(
            year: 2026,
            month: 3,
            day: 29,
            hour: 12,
            calendar: calendar
        )

        let interval = LocalDayInterval.containing(date, calendar: calendar)

        #expect(interval.duration == 23 * 60 * 60)
    }

    @Test("The autumn daylight-saving day lasts 25 hours")
    func handlesAutumnDaylightSavingChange() throws {
        let calendar = try makeCalendar(timeZone: "Europe/Bratislava")
        let date = try makeDate(
            year: 2026,
            month: 10,
            day: 25,
            hour: 12,
            calendar: calendar
        )

        let interval = LocalDayInterval.containing(date, calendar: calendar)

        #expect(interval.duration == 25 * 60 * 60)
    }

    @Test("The same instant follows each time zone's local day")
    func respectsTimeZoneAfterTravel() throws {
        let bratislava = try makeCalendar(timeZone: "Europe/Bratislava")
        let newYork = try makeCalendar(timeZone: "America/New_York")
        let instant = Date(timeIntervalSince1970: 1_789_120_800)

        let bratislavaDay = LocalDayInterval.containing(
            instant,
            calendar: bratislava
        )
        let newYorkDay = LocalDayInterval.containing(
            instant,
            calendar: newYork
        )

        #expect(bratislavaDay.start != newYorkDay.start)
        #expect(bratislava.component(.hour, from: bratislavaDay.start) == 0)
        #expect(newYork.component(.hour, from: newYorkDay.start) == 0)
        #expect(bratislavaDay.contains(instant))
        #expect(newYorkDay.contains(instant))
    }

    private func makeCalendar(timeZone identifier: String) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: identifier))
        return calendar
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0,
        second: Int = 0,
        calendar: Calendar
    ) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )))
    }
}
