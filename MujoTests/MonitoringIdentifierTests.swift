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

    @Test("The final window has one-minute thresholds")
    func plansFineThresholds() {
        let twoHours = AppConfiguration.Monitoring
            .usageThresholdMinutes(forLimitMinutes: 120)
        #expect(twoHours.contains(1))
        #expect(twoHours.contains(90))
        #expect(!twoHours.contains(104))
        #expect(twoHours.filter { (105...120).contains($0) } == Array(105...120))

        let fourHours = AppConfiguration.Monitoring
            .usageThresholdMinutes(forLimitMinutes: 240)
        #expect(!fourHours.contains(209))
        #expect(fourHours.filter { (210...240).contains($0) } == Array(210...240))

        let fifteenMinutes = AppConfiguration.Monitoring
            .usageThresholdMinutes(forLimitMinutes: 15)
        #expect(Array(fifteenMinutes.prefix(15)) == Array(1...15))
    }
}
