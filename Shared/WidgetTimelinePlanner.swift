//
//  WidgetTimelinePlanner.swift
//  Mujo
//

import Foundation

struct WidgetTimelinePlan {
    let date: Date
    let estimate: WidgetUsageEstimate
    let reloadAfter: Date
}

enum WidgetTimelinePlanner {
    static func makePlan(
        from snapshot: WidgetUsageSnapshot,
        at date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> WidgetTimelinePlan {
        WidgetTimelinePlan(
            date: date,
            estimate: WidgetUsageEstimator.estimate(
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
