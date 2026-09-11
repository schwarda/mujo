//
//  Time.swift
//  Mujo
//
//  Created by Aikari Studio on 09/09/2026.
//

import Foundation

enum TodayActivityDataState {
    case available
    case noData
}

struct TodayActivityConfiguration {
    let usedTime: TimeInterval
    let dataState: TodayActivityDataState
}

enum RemainingTimeCalculator {
    static func calculate(
        usedTime: TimeInterval,
        previewLimit: TimeInterval,
        storedLimit: TimeInterval,
        defaultLimit: TimeInterval = MujoShared.defaultDailyLimit
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

extension TimeInterval {
    func formatted() -> String {
        let totalMinutes = max(0, Int(self) / 60)

        guard totalMinutes > 0 else {
            return "Ø"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        return String(format: "%d:%02d", hours, minutes)
    }
}
