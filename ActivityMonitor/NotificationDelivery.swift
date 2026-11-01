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
        reachedUsedMinutes: Int,
        defaults: UserDefaults
    ) {
        guard let day = Calendar.current.ordinality(
            of: .day,
            in: .era,
            for: .now
        ) else { return }

        let dayID = String(day)
        let preferences = NotificationPreferences.load(from: defaults)
        guard NotificationMilestone.forLimit(
            minutes: limitMinutes, preferences: preferences
        ).contains(milestone) else { return }

        let kindID = milestone.percentage.map { "custom.\($0)" }
            ?? milestone.kind.rawValue
        // A new limit has its own future milestones, even if the same kind
        // was already delivered earlier today for the previous limit.
        let sentKey = "mujo.notification.sent.\(limitMinutes).\(kindID)"
        let minuteKey = "mujo.notification.sent.\(limitMinutes).minute.\(milestone.usedMinutes)"

        guard defaults.string(forKey: sentKey) != dayID,
              defaults.string(forKey: minuteKey) != dayID
        else { return }

        let remainingMinutes = max(0, limitMinutes - reachedUsedMinutes)
        let content = UNMutableNotificationContent()
        content.sound = .default

        switch milestone.kind {
        case .percent50:
            content.title = remainingTitle(minutes: remainingMinutes)
            content.body = "Be mindful of what remains."

        case .percent75:
            content.title = remainingTitle(minutes: remainingMinutes)
            content.body = "Your time is getting shorter. Spend it deliberately."

        case .finalWindow:
            content.title = "\(remainingMinutes) min remaining"
            content.body = "Make the last minutes count."

        case .fiveMinutesRemaining:
            content.title = "\(remainingMinutes) min remaining"
            content.body = "Choose how you want to spend them"

        case .timeExpired:
            content.title = "Nothing remains."
            content.body = "You've reached the time you chose for today."

        case .custom:
            content.title = remainingTitle(minutes: remainingMinutes)
            content.body = "Your reminder at \(milestone.percentage ?? 0)% used."
        }

        let request = UNNotificationRequest(
            identifier: "mujo.notification.\(dayID).\(limitMinutes).\(kindID)",
            content: content,
            trigger: nil
        )

        defaults.set(dayID, forKey: sentKey)
        defaults.set(dayID, forKey: minuteKey)

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
            if defaults.string(forKey: minuteKey) == dayID {
                defaults.removeObject(forKey: minuteKey)
            }
        }
    }

    private static func remainingTitle(minutes totalMinutes: Int) -> String {
        let hours = max(0, totalMinutes) / 60
        let minutes = max(0, totalMinutes) % 60
        let minuteUnit = "m"
        guard hours > 0 else {
            return "\(minutes) \(minuteUnit) remains"
        }

        let hourUnit = "h"
        return "\(hours)\(hourUnit) \(minutes)\(minuteUnit) remains"
    }
}
