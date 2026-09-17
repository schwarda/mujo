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
        let sentKey = "mujo.notification.sent.\(kindID)"

        guard defaults.string(forKey: sentKey) != dayID else { return }

        let remainingMinutes = limitMinutes - milestone.usedMinutes
        let remaining = String(
            format: "%d:%02d",
            remainingMinutes / 60,
            remainingMinutes % 60
        )

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.title = "\(remaining) remains"

        switch milestone.kind {
        case .percent50:
            content.body = "Be mindful of what remains."

        case .percent75:
            content.body = "Your time is getting shorter. Spend it deliberately."

        case .liveActivityInvitation:
            content.body = "Keep it in sight with Live Activity."
            content.userInfo = [
                "mujoAction": "startLiveActivity",
                "limitMinutes": limitMinutes,
                "remainingMinutes": remainingMinutes,
                "receivedAt": Date.now.timeIntervalSince1970
            ]
        }

        let request = UNNotificationRequest(
            identifier: "mujo.notification.\(dayID).\(kindID)",
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
}
