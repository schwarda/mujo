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
        let eventName = MujoShared.Monitoring.usageEventName(minutes: 15)

        #expect(
            MujoShared.Monitoring.usageCheckpointSeconds(from: eventName)
                == TimeInterval(15 * 60)
        )
    }

    @Test("Limit thresholds remain expressed in seconds")
    func parsesLimitThreshold() {
        let eventName = MujoShared.Monitoring.limitEventName(
            seconds: 2 * 60 * 60
        )

        #expect(
            MujoShared.Monitoring.limitSeconds(from: eventName)
                == TimeInterval(2 * 60 * 60)
        )
    }

    @Test("An event cannot be parsed as the other event type")
    func rejectsMismatchedEventTypes() {
        let usageEvent = MujoShared.Monitoring.usageEventName(minutes: 15)
        let limitEvent = MujoShared.Monitoring.limitEventName(seconds: 7_200)

        #expect(MujoShared.Monitoring.limitSeconds(from: usageEvent) == nil)
        #expect(
            MujoShared.Monitoring.usageCheckpointSeconds(from: limitEvent)
                == nil
        )
    }

    @Test(
        "Missing, malformed, zero, and negative thresholds are rejected",
        arguments: ["", "abc", "1.5", "0", "-1"]
    )
    func rejectsInvalidThresholds(_ suffix: String) {
        #expect(
            MujoShared.Monitoring.usageCheckpointSeconds(
                from: MujoShared.Monitoring.usageEventPrefix + suffix
            ) == nil
        )
        #expect(
            MujoShared.Monitoring.limitSeconds(
                from: MujoShared.Monitoring.limitEventPrefix + suffix
            ) == nil
        )
    }
}
