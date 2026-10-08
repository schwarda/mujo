import Foundation
import Testing
@testable import Mujo

@Suite("Report availability handshake")
struct ReportAvailabilityStoreTests {
    @Test("A report resolves only the active request")
    func resolvesCurrentRequest() throws {
        let suiteName = "ReportAvailabilityStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = ReportAvailabilityStore.begin(
            .onboardingHistory,
            defaults: defaults
        )
        #expect(first.status == .loading)

        ReportAvailabilityStore.resolveCurrent(
            .onboardingHistory,
            requestID: first.id,
            as: .hasData,
            defaults: defaults
        )
        let resolved = try #require(ReportAvailabilityStore.current(
            .onboardingHistory,
            defaults: defaults
        ))
        #expect(resolved.id == first.id)
        #expect(resolved.status == .hasData)

        let second = ReportAvailabilityStore.begin(
            .onboardingHistory,
            defaults: defaults
        )
        #expect(second.id != first.id)
        #expect(second.status == .loading)
    }

    @Test("Report kinds do not overwrite each other")
    func keepsKindsIndependent() throws {
        let suiteName = "ReportAvailabilityStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        _ = ReportAvailabilityStore.begin(
            .onboardingHistory,
            defaults: defaults
        )
        let limitEditor = ReportAvailabilityStore.begin(
            .limitEditor,
            defaults: defaults
        )
        ReportAvailabilityStore.resolveCurrent(
            .limitEditor,
            requestID: limitEditor.id,
            as: .noData,
            defaults: defaults
        )

        #expect(ReportAvailabilityStore.current(
            .onboardingHistory,
            defaults: defaults
        )?.status == .loading)
        #expect(ReportAvailabilityStore.current(
            .limitEditor,
            defaults: defaults
        )?.status == .noData)
    }

    @Test("A stale report cannot resolve a newer request")
    func staleReportCannotResolveNewRequest() throws {
        let suiteName = "ReportAvailabilityStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let stale = ReportAvailabilityStore.begin(
            .limitEditor,
            defaults: defaults
        )
        let current = ReportAvailabilityStore.begin(
            .limitEditor,
            defaults: defaults
        )
        ReportAvailabilityStore.resolveCurrent(
            .limitEditor,
            requestID: stale.id,
            as: .hasData,
            defaults: defaults
        )

        #expect(ReportAvailabilityStore.current(
            .limitEditor,
            defaults: defaults
        ) == current)
    }

    @Test("Onboarding history summary survives the process handoff")
    func persistsOnboardingHistorySummary() throws {
        let suiteName = "ReportAvailabilityStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let summary = OnboardingHistorySummary(
            averageMinutes: 210,
            suggestedMinutes: 180,
            availableDayCount: 5
        )

        OnboardingHistorySummaryStore.save(summary, defaults: defaults)
        #expect(OnboardingHistorySummaryStore.load(defaults: defaults) == summary)

        OnboardingHistorySummaryStore.clear(defaults: defaults)
        #expect(OnboardingHistorySummaryStore.load(defaults: defaults) == nil)
    }
}
