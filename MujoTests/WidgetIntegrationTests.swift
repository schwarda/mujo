//
//  WidgetIntegrationTests.swift
//  MujoTests
//

import Foundation
import Testing
@testable import Mujo

@Suite("Widget App Group integration")
struct WidgetIntegrationTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
    private let dayStart = Date(timeIntervalSince1970: 86_400_000)

    @Test("A stored checkpoint flows into the widget timeline")
    func loadsCheckpointIntoTimeline() throws {
        try withDefaults { defaults in
            defaults.set(
                3 * 60 * 60,
                forKey: AppConfiguration.DefaultsKey.dailyLimit
            )
            defaults.set(
                45 * 60,
                forKey: AppConfiguration.DefaultsKey.estimatedUsedTime
            )
            defaults.set(
                dayStart.timeIntervalSince1970,
                forKey: AppConfiguration.DefaultsKey.lastCheckpointResetDay
            )
            defaults.set(
                calendar.timeZone.identifier,
                forKey: AppConfiguration.DefaultsKey
                    .lastCheckpointTimeZoneIdentifier
            )
            defaults.set(
                dayStart.addingTimeInterval(-60).timeIntervalSince1970,
                forKey: AppConfiguration.DefaultsKey.usageMonitoringStartedAt
            )
            defaults.set(
                true,
                forKey: AppConfiguration.DefaultsKey.hasUsageCheckpoint
            )

            let plan = makePlan(defaults: defaults)

            #expect(plan.estimate.isAvailable)
            #expect(plan.estimate.remainingTime == 2 * 60 * 60 + 15 * 60)
            #expect(plan.reloadAfter == dayStart.addingTimeInterval(86_400))
        }
    }

    @Test("Changing the stored limit changes the next widget timeline")
    func loadsChangedLimit() throws {
        try withDefaults { defaults in
            configureAvailableEstimate(in: defaults)
            defaults.set(
                90 * 60,
                forKey: AppConfiguration.DefaultsKey.dailyLimit
            )

            let plan = makePlan(defaults: defaults)

            #expect(plan.estimate.isAvailable)
            #expect(plan.estimate.remainingTime == 90 * 60)
        }
    }

    @Test("Missing App Group values produce a waiting timeline")
    func handlesMissingData() throws {
        try withDefaults { defaults in
            let plan = makePlan(defaults: defaults)

            #expect(!plan.estimate.isAvailable)
            #expect(
                plan.estimate.remainingTime
                    == AppConfiguration.defaultDailyLimit
            )
        }
    }

    @Test("A timeline after midnight ignores yesterday's checkpoint")
    func resetsAtMidnight() throws {
        try withDefaults { defaults in
            configureAvailableEstimate(in: defaults)
            defaults.set(
                60 * 60,
                forKey: AppConfiguration.DefaultsKey.estimatedUsedTime
            )
            let tomorrow = dayStart.addingTimeInterval(24 * 60 * 60)

            let plan = makePlan(defaults: defaults, at: tomorrow)

            #expect(plan.estimate.isAvailable)
            #expect(plan.estimate.remainingTime == 3 * 60 * 60)
            #expect(
                plan.reloadAfter
                    == tomorrow.addingTimeInterval(24 * 60 * 60)
            )
        }
    }

    @Test("A time-zone mismatch produces a waiting timeline")
    func invalidatesAfterTimeZoneChange() throws {
        try withDefaults { defaults in
            configureAvailableEstimate(in: defaults)
            defaults.set(
                "Europe/Bratislava",
                forKey: AppConfiguration.DefaultsKey
                    .lastCheckpointTimeZoneIdentifier
            )

            let plan = makePlan(defaults: defaults)

            #expect(!plan.estimate.isAvailable)
            #expect(plan.estimate.remainingTime == 3 * 60 * 60)
        }
    }

    private func makePlan(
        defaults: UserDefaults,
        at date: Date? = nil
    ) -> WidgetTimelinePlan {
        let snapshot = WidgetUsageSnapshotLoader(defaults: defaults).load()

        return WidgetTimelinePlanner.makePlan(
            from: snapshot,
            at: date ?? dayStart.addingTimeInterval(12 * 60 * 60),
            calendar: calendar
        )
    }

    private func configureAvailableEstimate(in defaults: UserDefaults) {
        defaults.set(
            3 * 60 * 60,
            forKey: AppConfiguration.DefaultsKey.dailyLimit
        )
        defaults.set(
            dayStart.timeIntervalSince1970,
            forKey: AppConfiguration.DefaultsKey.lastCheckpointResetDay
        )
        defaults.set(
            calendar.timeZone.identifier,
            forKey: AppConfiguration.DefaultsKey
                .lastCheckpointTimeZoneIdentifier
        )
        defaults.set(
            dayStart.addingTimeInterval(-60).timeIntervalSince1970,
            forKey: AppConfiguration.DefaultsKey.usageMonitoringStartedAt
        )
        defaults.set(
            true,
            forKey: AppConfiguration.DefaultsKey.hasUsageCheckpoint
        )
    }

    private func withDefaults(
        _ test: (UserDefaults) throws -> Void
    ) throws {
        let suiteName = "WidgetIntegrationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        try test(defaults)
    }
}
