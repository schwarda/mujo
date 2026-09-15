//
//  WidgetTimelinePlanner.swift
//  Mujo
//

import Foundation

struct WidgetTimelinePlan {
    let date: Date
    let estimate: UsageEstimate
    let reloadAfter: Date
}

enum WidgetTimelinePlanner {
    static func makePlan(
        from snapshot: UsageSnapshot,
        at date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> WidgetTimelinePlan {
        WidgetTimelinePlan(
            date: date,
            estimate: UsageEstimator.estimate(
                from: snapshot,
                at: date,
                calendar: calendar
            ),
            reloadAfter: LocalDayInterval.containing(
                date,
                calendar: calendar
            ).end
        )
    }
}
