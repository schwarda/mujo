import Testing
@testable import Mujo

@Suite("Onboarding duration formatting")
struct OnboardingDurationFormatterTests {
    @Test("Empty selection uses the requested placeholder")
    func emptySelection() {
        #expect(
            OnboardingDurationFormatter.string(
                minutes: 0,
                emptyPlaceholder: "–"
            ) == "–"
        )
    }

    @Test("Sub-hour values stay compact")
    func minutesOnly() {
        #expect(OnboardingDurationFormatter.string(minutes: 15) == "15m")
        #expect(OnboardingDurationFormatter.string(minutes: 59) == "59m")
    }

    @Test("Hour values always reserve two minute digits")
    func hoursAndMinutes() {
        #expect(OnboardingDurationFormatter.string(minutes: 60) == "1h 00m")
        #expect(OnboardingDurationFormatter.string(minutes: 165) == "2h 45m")
    }

    @Test("Card durations use fixed hour and minute lines")
    func cardDuration() {
        #expect(
            OnboardingCardDurationFormatter.string(minutes: 45)
                == "0h\n45m"
        )
        #expect(
            OnboardingCardDurationFormatter.string(minutes: 1_470)
                == "24h\n30m"
        )
    }

    @Test("Year duration uses day and hour lines")
    func yearDuration() {
        #expect(
            OnboardingYearDurationFormatter.string(
                minutes: (53 * 24 + 5) * 60 + 30
            ) == "53d\n5h"
        )
    }

    @Test("Annual savings use projection when a full year is unavailable")
    func projectedAnnualSavings() {
        #expect(
            OnboardingAnnualSavingsCalculator.minutes(
                annualTotalMinutes: 1_470,
                recentDailyAverageMinutes: 210,
                availableDayCount: 7,
                dailyLimitMinutes: 120
            ) == 90 * 365
        )
    }

    @Test("Annual savings use the real total with full-year coverage")
    func actualAnnualSavings() {
        #expect(
            OnboardingAnnualSavingsCalculator.minutes(
                annualTotalMinutes: 70_000,
                recentDailyAverageMinutes: 210,
                availableDayCount: 365,
                dailyLimitMinutes: 120
            ) == 26_200
        )
    }
}
