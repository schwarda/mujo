//
//  CountdownWidget.swift
//  CountdownWidget
//
//  Created by Lopk Art on 09/09/2026.
//

import SwiftUI
import WidgetKit

struct CountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        return CountdownEntry(
            date: Date(),
            remainingTime: 3 * 60 * 60 + 45 * 60,
            isEstimateAvailable: false
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (CountdownEntry) -> Void
    ) {
        let plan = makePlan(at: .now)
        completion(CountdownEntry(plan: plan))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<CountdownEntry>) -> Void
    ) {
        let now = Date.now
        let plan = makePlan(at: now)

        completion(Timeline(
            entries: [CountdownEntry(plan: plan)],
            policy: .after(plan.reloadAfter)
        ))
    }

    private func makePlan(at date: Date) -> WidgetTimelinePlan {
        let defaults = UserDefaults(
            suiteName: AppConfiguration.appGroupIdentifier
        )
        let snapshot = UsageSnapshotLoader(defaults: defaults).load()

        return WidgetTimelinePlanner.makePlan(from: snapshot, at: date)
    }
}

struct CountdownEntry: TimelineEntry {
    let date: Date
    let remainingTime: TimeInterval
    let dailyLimit: TimeInterval
    let isEstimateAvailable: Bool

    init(
        date: Date,
        remainingTime: TimeInterval,
        dailyLimit: TimeInterval = AppConfiguration.defaultDailyLimit,
        isEstimateAvailable: Bool
    ) {
        self.date = date
        self.remainingTime = remainingTime
        self.dailyLimit = dailyLimit
        self.isEstimateAvailable = isEstimateAvailable
    }

    fileprivate init(plan: WidgetTimelinePlan) {
        self.init(
            date: plan.date,
            remainingTime: plan.estimate.remainingTime,
            dailyLimit: plan.dailyLimit,
            isEstimateAvailable: plan.estimate.isAvailable
        )
    }
}
