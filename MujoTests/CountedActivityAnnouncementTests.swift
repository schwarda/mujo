import Foundation
import Testing
@testable import Mujo

@Suite("Counted activity announcement")
@MainActor
struct CountedActivityAnnouncementTests {
    @Test("Eligibility depends on onboarding, the previous build, and any saved scope", arguments: [
        (true, "1.2 (17)", false, true),
        (true, nil, false, true),
        (true, "1.2 (18)", false, false),
        (true, "1.2 (19)", false, false),
        (true, "1.2 (17)", true, false),
        (false, "1.2 (17)", false, false),
        (false, nil, false, false)
    ] as [(Bool, String?, Bool, Bool)])
    func eligibility(
        completedOnboarding: Bool,
        recoveredBuild: String?,
        hasSavedScope: Bool,
        expectedPending: Bool
    ) {
        withDefaults { defaults in
            defaults.set(completedOnboarding, forKey: "hasCompletedOnboarding")
            defaults.set(recoveredBuild, forKey: "mujo.lastRecoveredBuild")

            let announcement = CountedActivityAnnouncement(defaults: defaults)
            #expect(announcement.resolvePending(hasSavedScope: hasSavedScope) == expectedPending)
        }
    }

    @Test("An upgrade stays pending across recovery until acknowledged")
    func survivesRecoveryUntilAcknowledged() {
        withDefaults { defaults in
            defaults.set(true, forKey: "hasCompletedOnboarding")
            defaults.set("1.2 (17)", forKey: "mujo.lastRecoveredBuild")
            #expect(CountedActivityAnnouncement(defaults: defaults).resolvePending(hasSavedScope: false))

            defaults.set("1.2 (18)", forKey: "mujo.lastRecoveredBuild")
            let announcement = CountedActivityAnnouncement(defaults: defaults)
            #expect(announcement.resolvePending(hasSavedScope: false))

            announcement.acknowledge()
            #expect(!CountedActivityAnnouncement(defaults: defaults).resolvePending(hasSavedScope: false))
        }
    }

    @Test("A fresh install stays ineligible after finishing onboarding")
    func staysIneligibleAfterOnboarding() {
        withDefaults { defaults in
            let announcement = CountedActivityAnnouncement(defaults: defaults)
            #expect(!announcement.resolvePending(hasSavedScope: false))

            defaults.set(true, forKey: "hasCompletedOnboarding")
            #expect(!announcement.resolvePending(hasSavedScope: false))
        }
    }

    private func withDefaults(_ assertions: (UserDefaults) -> Void) {
        let suiteName = "AikariStudio.MujoTests.CountedActivityAnnouncement.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        assertions(defaults)
    }
}
