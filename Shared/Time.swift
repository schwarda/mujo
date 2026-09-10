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
