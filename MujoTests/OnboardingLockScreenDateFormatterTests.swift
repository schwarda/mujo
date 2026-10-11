import Foundation
import Testing
@testable import Mujo

@Suite("Onboarding Lock Screen date formatting")
struct OnboardingLockScreenDateFormatterTests {
    @Test("The preview uses its existing weekday, day, and 24-hour formats")
    func formatsDateAndTime() throws {
        let timeZone = try #require(TimeZone(secondsFromGMT: 0))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: 26,
            hour: 17,
            minute: 11
        )))

        let display = OnboardingLockScreenDateFormatter.display(
            for: date,
            timeZone: timeZone
        )

        #expect(display.date == "Sat 26")
        #expect(display.time == "17:11")
    }
}
