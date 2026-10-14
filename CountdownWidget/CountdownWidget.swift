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
#if DEBUG
        defaults?.set(
            date.timeIntervalSince1970,
            forKey: AppConfiguration.DefaultsKey.lastWidgetTimelineAt
        )
        DiagnosticsStore.record(
            source: "widget",
            message: "Timeline generated",
            defaults: defaults
        )
#endif
        let snapshot = UsageSnapshotLoader(defaults: defaults).load()

        return WidgetTimelinePlanner.makePlan(from: snapshot, at: date)
    }
}

struct CountdownEntry: TimelineEntry {
    let date: Date
    let remainingTime: TimeInterval
    let usedTime: TimeInterval
    let dailyLimit: TimeInterval
    let isEstimateAvailable: Bool
    let unavailableReason: UsageEstimate.UnavailableReason?

    init(
        date: Date,
        remainingTime: TimeInterval,
        usedTime: TimeInterval? = nil,
        dailyLimit: TimeInterval = AppConfiguration.defaultDailyLimit,
        isEstimateAvailable: Bool,
        unavailableReason: UsageEstimate.UnavailableReason? = nil
    ) {
        self.date = date
        self.remainingTime = remainingTime
        self.usedTime = usedTime
            ?? min(max(0, dailyLimit - remainingTime), max(0, dailyLimit))
        self.dailyLimit = dailyLimit
        self.isEstimateAvailable = isEstimateAvailable
        self.unavailableReason = unavailableReason
    }

    fileprivate init(plan: WidgetTimelinePlan) {
        self.init(
            date: plan.date,
            remainingTime: plan.estimate.remainingTime,
            usedTime: plan.estimate.usedTime,
            dailyLimit: plan.dailyLimit,
            isEstimateAvailable: plan.estimate.isAvailable,
            unavailableReason: plan.estimate.unavailableReason
        )
    }

    var unavailableMessage: String {
        isAdjustingTimeZone
            ? "Syncing time zone…"
            : "Updating…"
    }

    var isAdjustingTimeZone: Bool {
        unavailableReason == .timeZoneChanged
    }

    var isExhausted: Bool {
        isEstimateAvailable && remainingTime <= 0
    }

}
