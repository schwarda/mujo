import Foundation

struct CountedActivityAnnouncement {
    private static let pendingKey = "mujo.countedActivityAnnouncementPending"
    private static let firstPickerBuild = 18

    let defaults: UserDefaults

    func resolvePending(hasSavedScope: Bool) -> Bool {
        let stored = defaults.object(forKey: Self.pendingKey) as? Bool
        let isPending = !hasSavedScope && (stored ?? isEligible)
        if stored != isPending {
            defaults.set(isPending, forKey: Self.pendingKey)
        }
        return isPending
    }

    func acknowledge() {
        defaults.set(false, forKey: Self.pendingKey)
    }

    private var isEligible: Bool {
        guard defaults.bool(forKey: "hasCompletedOnboarding") else { return false }
        let lastBuild = AppUpdateRecovery(defaults: defaults).lastRecoveredBuildNumber
        return lastBuild.map { $0 < Self.firstPickerBuild } ?? true
    }
}
