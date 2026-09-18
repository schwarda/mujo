//
//  NotificationMilestone.swift
//  Mujo
//
//  Created by Aikari Studio on 16/09/2026.
//

/*
 Notification hits for every selectable daily limit (h:mm).
 Each cell is used time → remaining time; — means no notification.
 The last column is the notification that invites the user to start a
 Live Activity. Its one-minute updates are not additional notifications.

 Limit | 50%         | 75%         | Live Activity invitation
 ------+-------------+-------------+-------------------------
 0:15  | —           | —           | 0:01→0:14
 0:30  | —           | —           | 0:15→0:15
 0:45  | —           | —           | 0:30→0:15
 1:00  | 0:30→0:30   | —           | 0:45→0:15
 1:15  | 0:45→0:30   | —           | 1:00→0:15
 1:30  | 0:45→0:45   | —           | 1:15→0:15
 1:45  | 1:00→0:45   | —           | 1:30→0:15
 2:00  | 1:00→1:00   | 1:30→0:30   | 1:45→0:15
 2:15  | 1:15→1:00   | 1:45→0:30   | 2:00→0:15
 2:30  | 1:15→1:15   | 2:00→0:30   | 2:15→0:15
 2:45  | 1:30→1:15   | 2:15→0:30   | 2:30→0:15
 3:00  | 1:30→1:30   | 2:15→0:45   | 2:45→0:15
 3:15  | 1:45→1:30   | 2:30→0:45   | 3:00→0:15
 3:30  | 1:45→1:45   | 2:45→0:45   | 3:15→0:15
 3:45  | 2:00→1:45   | 3:00→0:45   | 3:30→0:15
 4:00  | 2:00→2:00   | 3:00→1:00   | 3:30→0:30
 4:15  | 2:15→2:00   | 3:15→1:00   | 3:45→0:30
 4:30  | 2:15→2:15   | 3:30→1:00   | 4:00→0:30
 4:45  | 2:30→2:15   | 3:45→1:00   | 4:15→0:30
 5:00  | 2:30→2:30   | 3:45→1:15   | 4:30→0:30
 5:15  | 2:45→2:30   | 4:00→1:15   | 4:45→0:30
 5:30  | 2:45→2:45   | 4:15→1:15   | 5:00→0:30
 5:45  | 3:00→2:45   | 4:30→1:15   | 5:15→0:30
 6:00  | 3:00→3:00   | 4:30→1:30   | 5:30→0:30
 6:15  | 3:15→3:00   | 4:45→1:30   | 5:45→0:30
 6:30  | 3:15→3:15   | 5:00→1:30   | 6:00→0:30
 6:45  | 3:30→3:15   | 5:15→1:30   | 6:15→0:30
 7:00  | 3:30→3:30   | 5:15→1:45   | 6:30→0:30
 7:15  | 3:45→3:30   | 5:30→1:45   | 6:45→0:30
 7:30  | 3:45→3:45   | 5:45→1:45   | 7:00→0:30
 7:45  | 4:00→3:45   | 6:00→1:45   | 7:15→0:30
 8:00  | 4:00→4:00   | 6:00→2:00   | 7:30→0:30
 8:15  | 4:15→4:00   | 6:15→2:00   | 7:45→0:30
 8:30  | 4:15→4:15   | 6:30→2:00   | 8:00→0:30
 8:45  | 4:30→4:15   | 6:45→2:00   | 8:15→0:30
 9:00  | 4:30→4:30   | 6:45→2:15   | 8:30→0:30
 9:15  | 4:45→4:30   | 7:00→2:15   | 8:45→0:30
 9:30  | 4:45→4:45   | 7:15→2:15   | 9:00→0:30
 9:45  | 5:00→4:45   | 7:30→2:15   | 9:15→0:30
 10:00 | 5:00→5:00   | 7:30→2:30   | 9:30→0:30
 10:15 | 5:15→5:00   | 7:45→2:30   | 9:45→0:30
 10:30 | 5:15→5:15   | 8:00→2:30   | 10:00→0:30
 10:45 | 5:30→5:15   | 8:15→2:30   | 10:15→0:30
 11:00 | 5:30→5:30   | 8:15→2:45   | 10:30→0:30
 11:15 | 5:45→5:30   | 8:30→2:45   | 10:45→0:30
 11:30 | 5:45→5:45   | 8:45→2:45   | 11:00→0:30
 11:45 | 6:00→5:45   | 9:00→2:45   | 11:15→0:30
 12:00 | 6:00→6:00   | 9:00→3:00   | 11:30→0:30
*/

struct NotificationMilestone {
    enum Kind: String {
        case percent50
        case percent75
        case liveActivityInvitation
    }

    let kind: Kind
    let usedMinutes: Int
    
    nonisolated static func forLimit(minutes: Int) -> [Self] {
        let limit = AppConfiguration.DailyLimit.normalizedMinutes(minutes)
        let step = AppConfiguration.DailyLimit.stepMinutes
        let liveRemaining = AppConfiguration.DailyLimit
            .liveActivityWindowMinutes(forLimitMinutes: limit)

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
