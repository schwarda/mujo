//
//  MonitoringIdentifierTests.swift
//  MujoTests
//

import FamilyControls
import Foundation
import Testing
@testable import Mujo

@Suite("Shared monitoring identifiers")
struct MonitoringIdentifierTests {
    @Test("A stored scope selects its registration and missing scope preserves legacy defaults")
    func loadsCountedScope() throws {
        let suite = "MonitoringIdentifierTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let legacy = try CountedActivityScope.load(from: defaults)
        #expect(legacy.selection.countsAllActivity)
        #expect(legacy.activityName == AppConfiguration.Monitoring.usageActivityName)

        let generation = UUID()
        let selection = try CountedActivityScope.encodeSelection(FamilyActivitySelection())
        defaults.set(
            [
                AppConfiguration.Monitoring.scopeGenerationKey: generation.uuidString,
                AppConfiguration.Monitoring.scopeSelectionKey: selection
            ],
            forKey: AppConfiguration.DefaultsKey.countedActivityScope
        )
        let saved = try CountedActivityScope.load(from: defaults)
        #expect(saved.selection.countsAllActivity)
        #expect(saved.activityName == AppConfiguration.Monitoring.scopedActivityName(generation: generation))
        #expect(AppConfiguration.Monitoring.activeUsageActivityName(in: defaults) == saved.activityName)
    }

    @Test("A malformed stored scope cannot fall back to monitoring all activity")
    func rejectsMalformedScope() throws {
        let suite = "MonitoringIdentifierTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("bad scope", forKey: AppConfiguration.DefaultsKey.countedActivityScope)

        #expect(throws: CountedActivityScope.StorageError.self) {
            try CountedActivityScope.load(from: defaults)
        }
        #expect(AppConfiguration.Monitoring.activeUsageActivityName(in: defaults) == nil)
    }

    @Test("A selection requiring new authorization does not activate the default monitor")
    func requiresFreshSelection() throws {
        let suite = "MonitoringIdentifierTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: AppConfiguration.DefaultsKey.hasUsageCheckpoint)
        defaults.set(1_800.0, forKey: AppConfiguration.DefaultsKey.estimatedUsedTime)
        defaults.set(
            [AppConfiguration.Monitoring.scopeNeedsReselectionKey: true],
            forKey: AppConfiguration.DefaultsKey.countedActivityScope
        )

        #expect(throws: CountedActivityScope.StorageError.authorizationChanged) {
            try CountedActivityScope.load(from: defaults)
        }
        #expect(AppConfiguration.Monitoring.activeUsageActivityName(in: defaults) == nil)
        let snapshot = UsageSnapshotLoader(defaults: defaults).load()
        #expect(!snapshot.hasCheckpoint)
        #expect(snapshot.estimatedUsedTime == 0)
    }

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
