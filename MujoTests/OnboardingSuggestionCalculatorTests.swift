import Foundation
import Testing
@testable import Mujo

@Suite("Onboarding suggestion calculation")
struct OnboardingSuggestionCalculatorTests {
    @Test("Empty activity remains unavailable")
    func emptyActivity() {
        let configuration = OnboardingSuggestionCalculator.configuration(
            dailyTotals: [:],
            averageScope: .recentDays,
            dailyLimitMinutes: nil
        )

        #expect(configuration.totalMinutes == nil)
        #expect(configuration.averageMinutes == nil)
        #expect(configuration.availableDayCount == 0)
    }

    @Test("Recent scope excludes activity older than seven available days")
    func recentAverage() {
        let configuration = OnboardingSuggestionCalculator.configuration(
            dailyTotals: dailyTotals,
            averageScope: .recentDays,
            dailyLimitMinutes: 120
        )

        #expect(configuration.totalMinutes == 2_160)
        #expect(configuration.recentTotalMinutes == 2_100)
        #expect(configuration.averageMinutes == 300)
        #expect(configuration.suggestedMinutes == 255)
        #expect(configuration.dailyLimitMinutes == 120)
        #expect(configuration.availableDayCount == 8)
        #expect(configuration.recentAvailableDayCount == 7)
    }

    @Test("All-days scope uses every available day")
    func allDaysAverage() {
        let configuration = OnboardingSuggestionCalculator.configuration(
            dailyTotals: dailyTotals,
            averageScope: .allAvailableDays,
            dailyLimitMinutes: nil
        )

        #expect(configuration.averageMinutes == 270)
        #expect(configuration.suggestedMinutes == 225)
    }

    private var dailyTotals: [Date: TimeInterval] {
        let calendar = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        return Dictionary(uniqueKeysWithValues: (1...8).map { day in
            let date = calendar.date(byAdding: .day, value: day, to: start)!
            return (date, TimeInterval(day * 60 * 60))
        })
    }
}
