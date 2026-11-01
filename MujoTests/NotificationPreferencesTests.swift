import Foundation
import Testing
@testable import Mujo

@Suite("Notification preferences")
struct NotificationPreferencesTests {
    @Test("Existing installs keep alerts, expiry and badges enabled")
    func defaultsAndPersistence() throws {
        let name = "NotificationPreferencesTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let initial = NotificationPreferences.load(from: defaults)
        #expect(initial.recommendedEnabled)
        #expect(initial.limitReachedEnabled)
        #expect(initial.badgeEnabled)
        #expect(initial.customPercentages.isEmpty)

        let changed = NotificationPreferences(
            recommendedEnabled: false,
            limitReachedEnabled: true,
            badgeEnabled: false,
            customPercentages: [80, 25, 80, 0, 100, -1]
        )
        changed.save(to: defaults)
        #expect(NotificationPreferences.load(from: defaults) == changed)
        #expect(changed.customPercentages == [25, 80])
    }

    @Test("Custom alerts remain independent of recommended alerts and expiry")
    func independentChoices() {
        let preferences = NotificationPreferences(
            recommendedEnabled: false,
            limitReachedEnabled: false,
            customPercentages: [20, 80]
        )
        let milestones = NotificationMilestone.forLimit(
            minutes: 120, preferences: preferences
        )
        #expect(milestones.map(\.usedMinutes) == [24, 96])
        #expect(milestones.map(\.percentage) == [20, 80])
    }

    @Test("Coincident recommended and custom alerts produce one notification")
    func coalescesAlerts() {
        let milestones = NotificationMilestone.forLimit(
            minutes: 120,
            preferences: NotificationPreferences(customPercentages: [50, 75, 80])
        )
        #expect(milestones.map(\.usedMinutes) == [60, 90, 96, 105, 115, 120])
    }

    @Test("Short limits round custom percentages up and merge coincident minutes")
    func shortLimitRounding() {
        let milestones = NotificationMilestone.forLimit(
            minutes: 15,
            preferences: NotificationPreferences(
                recommendedEnabled: false,
                limitReachedEnabled: false,
                customPercentages: [1, 2, 33, 99]
            )
        )
        #expect(milestones.map(\.usedMinutes) == [1, 5, 15])
    }

    @Test("Late checkpoints send the latest crossed alert without replaying old alerts")
    func crossedCheckpoints() {
        let preferences = NotificationPreferences(
            recommendedEnabled: false,
            limitReachedEnabled: false,
            customPercentages: [20, 25, 80]
        )
        let alert = NotificationMilestone.latestCrossed(
            forLimitMinutes: 120,
            previousUsedMinutes: 15,
            reachedUsedMinutes: 30,
            preferences: preferences
        )
        #expect(alert?.usedMinutes == 30)
        #expect(NotificationMilestone.latestCrossed(
            forLimitMinutes: 120,
            previousUsedMinutes: 30,
            reachedUsedMinutes: 45,
            preferences: preferences
        ) == nil)
    }

    @Test("Monitoring registers custom minutes without removing measurement checkpoints")
    func customThresholds() {
        let thresholds = AppConfiguration.Monitoring.usageThresholdMinutes(
            forLimitMinutes: 120, customPercentages: [20, 80]
        )
        #expect(thresholds.contains(24))
        #expect(thresholds.contains(96))
        #expect(thresholds.contains(1))
        #expect(thresholds.contains(720))
        #expect(thresholds.filter { (105...120).contains($0) } == Array(105...120))
    }
}
