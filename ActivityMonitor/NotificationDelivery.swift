//
//  NotificationDelivery.swift
//  Mujo
//
//  Created by Aikari Studio on 16/09/2026.
//

import Foundation
import OSLog
import UserNotifications

enum NotificationDelivery {
    private static let logger = Logger(
        subsystem: "AikariStudio.Mujo",
        category: "NotificationDelivery"
    )

    static func send(
        _ milestone: NotificationMilestone,
        limitMinutes: Int,
        defaults: UserDefaults
    ) {
        guard let day = Calendar.current.ordinality(
            of: .day,
            in: .era,
            for: .now
        ) else { return }

        let dayID = String(day)
        let kindID = milestone.kind.rawValue
        // A new limit has its own future milestones, even if the same kind
        // was already delivered earlier today for the previous limit.
        let sentKey = "mujo.notification.sent.\(limitMinutes).\(kindID)"

        guard defaults.string(forKey: sentKey) != dayID else { return }

        let remainingMinutes = limitMinutes - milestone.usedMinutes
        let content = UNMutableNotificationContent()
        content.sound = .default

        switch milestone.kind {
        case .percent50:
            content.title = remainingTitle(minutes: remainingMinutes)
            content.body = "Be mindful of what remains."

        case .percent75:
            content.title = remainingTitle(minutes: remainingMinutes)
            content.body = "Your time is getting shorter. Spend it deliberately."

        case .liveActivityInvitation:
            content.title = remainingTitle(minutes: remainingMinutes)
            content.body = "Keep it in sight with Live Activity."
            content.userInfo = [
                "mujoAction": "startLiveActivity",
                "limitMinutes": limitMinutes,
                "remainingMinutes": remainingMinutes,
                "receivedAt": Date.now.timeIntervalSince1970
            ]

        case .timeExpired:
            content.title = "Nothing remains."
            content.body = "You've reached the time you chose for today."
        }

        let request = UNNotificationRequest(
            identifier: "mujo.notification.\(dayID).\(limitMinutes).\(kindID)",
            content: content,
            trigger: nil
        )

        defaults.set(dayID, forKey: sentKey)

        UNUserNotificationCenter.current().add(request) { error in
            guard let error else { return }

            logger.error(
                "Could not schedule notification: \(error.localizedDescription, privacy: .public)"
            )

            guard let defaults = UserDefaults(
                suiteName: AppConfiguration.appGroupIdentifier
            ),
                  defaults.string(forKey: sentKey) == dayID
            else { return }

            defaults.removeObject(forKey: sentKey)
        }
    }

    private static func remainingTitle(minutes totalMinutes: Int) -> String {
        let hours = max(0, totalMinutes) / 60
        let minutes = max(0, totalMinutes) % 60
        let minuteUnit = "min"
        guard hours > 0 else {
            return "\(minutes) \(minuteUnit) remains"
        }

        let hourUnit = "h"
        return "\(hours) \(hourUnit) \(minutes) \(minuteUnit) remains"
    }
}
