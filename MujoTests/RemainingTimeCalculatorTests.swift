//
//  RemainingTimeCalculatorTests.swift
//  MujoTests
//

import Foundation
import Testing
@testable import Mujo

struct RemainingTimeCalculatorTests {
    @Test func previewLimitTakesPriorityOverStoredLimit() {
        let remainingTime = RemainingTimeCalculator.calculate(
            usedTime: 30 * 60,
            previewLimit: 90 * 60,
            storedLimit: 3 * 60 * 60
        )

        #expect(remainingTime == 60 * 60)
    }

    @Test func storedLimitIsUsedWhenPreviewIsMissing() {
        let remainingTime = RemainingTimeCalculator.calculate(
            usedTime: 30 * 60,
            previewLimit: 0,
            storedLimit: 2 * 60 * 60
        )

        #expect(remainingTime == 90 * 60)
    }

    @Test func invalidPreviewFallsBackToStoredLimit() {
        let remainingTime = RemainingTimeCalculator.calculate(
            usedTime: 30 * 60,
            previewLimit: -1,
            storedLimit: 2 * 60 * 60
        )

        #expect(remainingTime == 90 * 60)
    }

    @Test func defaultLimitIsUsedWhenSavedLimitsAreMissing() {
        let remainingTime = RemainingTimeCalculator.calculate(
            usedTime: 30 * 60,
            previewLimit: 0,
            storedLimit: 0
        )

        #expect(remainingTime == AppConfiguration.defaultDailyLimit - (30 * 60))
    }

    @Test func remainingTimeCannotBeNegative() {
        let remainingTime = RemainingTimeCalculator.calculate(
            usedTime: 3 * 60 * 60,
            previewLimit: 0,
            storedLimit: 2 * 60 * 60
        )

        #expect(remainingTime == 0)
    }
}
