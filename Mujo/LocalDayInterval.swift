//
//  LocalDayInterval.swift
//  Mujo
//

import Foundation

enum LocalDayInterval {
    static func containing(
        _ date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(
            byAdding: .day,
            value: 1,
            to: start
        ) ?? start.addingTimeInterval(24 * 60 * 60)

        return DateInterval(start: start, end: end)
    }
}
