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
    }
}
