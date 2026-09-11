//
//  MonitoringIdentifierTests.swift
//  MujoTests
//

import Testing
@testable import Mujo

@Suite("Shared monitoring identifiers")
struct MonitoringIdentifierTests {
    @Test("Usage events include their checkpoint in minutes")
    func createsUsageEventNames() {
        #expect(
            AppConfiguration.Monitoring.usageEventName(minutes: 15)
                == "mujo.usage.15"
        )
        #expect(
            AppConfiguration.Monitoring.usageEventName(minutes: 12 * 60)
                == "mujo.usage.720"
        )
    }

    @Test("Limit events include their threshold in seconds")
    func createsLimitEventNames() {
        #expect(
            AppConfiguration.Monitoring.limitEventName(seconds: 5 * 60 * 60)
                == "mujo.limit.18000"
        )
    }
}
