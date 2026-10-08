//
//  NotificationMilestoneTests.swift
//  MujoTests
//

import Testing
@testable import Mujo

@Suite("Notification milestones")
struct NotificationMilestoneTests {
    @Test("Short limits notify at the final window, five minutes, and expiry")
    func shortLimits() {
        for (limit, finalWindowStart) in [(15, 1), (30, 15), (45, 30)] {
            let milestones = NotificationMilestone.forLimit(minutes: limit)
            #expect(milestones.map(\.kind) == [
                .finalWindow, .fiveMinutesRemaining, .timeExpired
            ])
            #expect(milestones.map(\.usedMinutes) == [
                finalWindowStart, limit - 5, limit
            ])
        }
    }

    @Test("A two-hour limit includes 15-minute and 5-minute warnings")
    func twoHours() {
        let milestones = NotificationMilestone.forLimit(minutes: 120)
        #expect(milestones.map(\.kind) == [
            .percent50, .percent75, .finalWindow,
            .fiveMinutesRemaining, .timeExpired
        ])
        #expect(milestones.map(\.usedMinutes) == [60, 90, 105, 115, 120])
    }

    @Test("Four hours switches to a 30-minute final window")
    func fourHours() {
        let milestones = NotificationMilestone.forLimit(minutes: 240)
        #expect(milestones.map(\.usedMinutes) == [120, 180, 210, 235, 240])
    }

    @Test("Every selectable limit has all notification events registered")
    func everyMilestoneHasAUsageThreshold() {
        for limit in stride(from: 15, through: 720, by: 15) {
            let thresholds = Set(AppConfiguration.Monitoring
                .usageThresholdMinutes(forLimitMinutes: limit))
            for milestone in NotificationMilestone.forLimit(minutes: limit) {
                #expect(thresholds.contains(milestone.usedMinutes))
            }
        }
    }
}
