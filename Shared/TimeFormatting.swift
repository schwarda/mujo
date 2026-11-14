//
//  TimeFormatting.swift
//  Mujo
//
//  Created by Aikari Studio on 09/09/2026.
//

import Foundation

extension TimeInterval {
    nonisolated var accessibilityDuration: String {
        let totalMinutes = max(0, Int(self / 60))
        let formatter = DateComponentsFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: Bundle.main.preferredLocalizations.first
            ?? Bundle.main.developmentLocalization ?? "en")
        formatter.calendar = calendar
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: TimeInterval(totalMinutes) * 60)
            ?? String(localized: "0 minutes")
    }

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
