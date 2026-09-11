//
//  MujoTests.swift
//  MujoTests
//
//  Created by Aikari Studio on 05/09/2026.
//

import Foundation
import Testing
@testable import Mujo

@Suite("Time formatting")
struct TimeFormattingTests {
    @Test("Zero and negative durations use the empty-time symbol")
    func formatsEmptyTime() {
        #expect(TimeInterval(0).formatted() == "Ø")
        #expect(TimeInterval(59).formatted() == "Ø")
        #expect(TimeInterval(-60).formatted() == "Ø")
    }

    @Test("Durations are truncated to whole minutes")
    func formatsHoursAndMinutes() {
        #expect(TimeInterval(60).formatted() == "0:01")
        #expect(TimeInterval(3_599).formatted() == "0:59")
        #expect(TimeInterval(3_600).formatted() == "1:00")
        #expect(TimeInterval(13_379).formatted() == "3:42")
    }
}

@Suite("Shared monitoring identifiers")
struct MonitoringIdentifierTests {
    @Test("Usage events include their checkpoint in minutes")
    func createsUsageEventNames() {
        #expect(
            MujoShared.Monitoring.usageEventName(minutes: 15)
                == "mujo.usage.15"
        )
        #expect(
            MujoShared.Monitoring.usageEventName(minutes: 12 * 60)
                == "mujo.usage.720"
        )
    }

    @Test("Limit events include their threshold in seconds")
    func createsLimitEventNames() {
        #expect(
            MujoShared.Monitoring.limitEventName(seconds: 5 * 60 * 60)
                == "mujo.limit.18000"
        )
    }
}
