//
//  TimeFormatting.swift
//  Mujo
//
//  Created by Aikari Studio on 09/09/2026.
//

import Foundation

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
