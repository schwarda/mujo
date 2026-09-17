//
//  NotificationMilestone.swift
//  Mujo
//
//  Created by Aikari Studio on 16/09/2026.
//

struct NotificationMilestone {
    enum Kind: String {
        case percent50
        case percent75
        case liveActivityInvitation
    }

    let kind: Kind
    let usedMinutes: Int
    
    nonisolated func eventName(forLimitMinutes minutes: Int) -> String {
        let limit = AppConfiguration.DailyLimit.normalizedMinutes(minutes)
        let activityName = AppConfiguration.Monitoring.notificationActivityName

        return "\(activityName).\(limit).\(kind.rawValue)"
    }
    
    nonisolated static func forLimit(minutes: Int) -> [Self] {
        let limit = AppConfiguration.DailyLimit.normalizedMinutes(minutes)
        let step = AppConfiguration.DailyLimit.stepMinutes
        let liveRemaining = limit >= 4 * 60 ? 30 : 15

        var milestones: [Self] = []

        if limit >= 60 {
            let halfRemaining = (limit / 2 / step) * step
            if halfRemaining > liveRemaining {
                milestones.append(
                    Self(kind: .percent50, usedMinutes: limit - halfRemaining)
                )
            }

            let quarterRemaining = (limit / 4 / step) * step
            if quarterRemaining > liveRemaining {
                milestones.append(
                    Self(kind: .percent75, usedMinutes: limit - quarterRemaining)
                )
            }
        }

        milestones.append(
            Self(
                kind: .liveActivityInvitation,
                usedMinutes: max(1, limit - liveRemaining)
            )
        )

        return milestones
    }
}

