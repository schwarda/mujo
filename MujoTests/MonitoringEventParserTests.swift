//
//  MonitoringEventParserTests.swift
//  MujoTests
//

import Foundation
import Testing
@testable import Mujo

@Suite("Monitoring event parsing")
struct MonitoringEventParserTests {
    @Test("Usage checkpoints are converted from minutes to seconds")
    func parsesUsageCheckpoint() {
        let eventName = AppConfiguration.Monitoring.usageEventName(minutes: 15)

        #expect(
            AppConfiguration.Monitoring.usageCheckpointSeconds(from: eventName)
                == TimeInterval(15 * 60)
        )
    }

    @Test("Limit thresholds remain expressed in seconds")
    func parsesLimitThreshold() {
        let eventName = AppConfiguration.Monitoring.limitEventName(
            seconds: 2 * 60 * 60
        )

        #expect(
            AppConfiguration.Monitoring.limitSeconds(from: eventName)
                == TimeInterval(2 * 60 * 60)
        )
    }

    @Test("An event cannot be parsed as the other event type")
    func rejectsMismatchedEventTypes() {
        let usageEvent = AppConfiguration.Monitoring.usageEventName(minutes: 15)
        let limitEvent = AppConfiguration.Monitoring.limitEventName(seconds: 7_200)

        #expect(AppConfiguration.Monitoring.limitSeconds(from: usageEvent) == nil)
        #expect(
            AppConfiguration.Monitoring.usageCheckpointSeconds(from: limitEvent)
                == nil
        )
    }

    @Test(
        "Missing, malformed, zero, and negative thresholds are rejected",
        arguments: ["", "abc", "1.5", "0", "-1"]
    )
    func rejectsInvalidThresholds(_ suffix: String) {
        #expect(
            AppConfiguration.Monitoring.usageCheckpointSeconds(
                from: AppConfiguration.Monitoring.usageEventPrefix + suffix
            ) == nil
        )
        #expect(
            AppConfiguration.Monitoring.limitSeconds(
                from: AppConfiguration.Monitoring.limitEventPrefix + suffix
            ) == nil
        )
    }
}
