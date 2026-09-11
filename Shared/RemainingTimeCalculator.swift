//
//  RemainingTimeCalculator.swift
//  Mujo
//

import Foundation

enum RemainingTimeCalculator {
    static func calculate(
        usedTime: TimeInterval,
        previewLimit: TimeInterval,
        storedLimit: TimeInterval,
        defaultLimit: TimeInterval = AppConfiguration.defaultDailyLimit
    ) -> TimeInterval {
        let dailyLimit: TimeInterval

        if previewLimit > 0 {
            dailyLimit = previewLimit
        } else if storedLimit > 0 {
            dailyLimit = storedLimit
        } else {
            dailyLimit = defaultLimit
        }

        return max(0, dailyLimit - usedTime)
    }
}
