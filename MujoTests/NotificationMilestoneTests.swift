//
//  NotificationMilestoneTests.swift
//  MujoTests
//

import Testing
@testable import Mujo

@Suite("Notification milestones")
struct NotificationMilestoneTests {
    @Test("Short limits invite only into Live Activity")
    func shortLimits() {
        for (limit, invitation) in [(15, 1), (30, 15), (45, 30)] {
            let milestones = NotificationMilestone.forLimit(minutes: limit)
            #expect(milestones.count == 1)
            #expect(milestones.first?.kind == .liveActivityInvitation)
            #expect(milestones.first?.usedMinutes == invitation)
        }
    }

    @Test("A two-hour limit has 50%, 75%, and a 15-minute invitation")
    func twoHours() {
        let milestones = NotificationMilestone.forLimit(minutes: 120)
        #expect(milestones.map(\.kind) == [
            .percent50, .percent75, .liveActivityInvitation
        ])
        #expect(milestones.map(\.usedMinutes) == [60, 90, 105])
    }

    @Test("Four hours switches to a 30-minute final window")
    func fourHours() {
        let milestones = NotificationMilestone.forLimit(minutes: 240)
        #expect(milestones.map(\.usedMinutes) == [120, 180, 210])
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
