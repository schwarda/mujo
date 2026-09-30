//
//  RemainingTimeBadge.swift
//  Mujo
//

import Foundation
import OSLog
import UserNotifications

enum RemainingTimeBadge {
    private static let logger = Logger(
        subsystem: "AikariStudio.Mujo",
        category: "RemainingTimeBadge"
    )

    static func update(
        from snapshot: UsageSnapshot,
        at date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        let count = badgeCount(
            from: snapshot,
            at: date,
            calendar: calendar
        ) ?? 0

        UNUserNotificationCenter.current().setBadgeCount(count) { error in
            guard let error else { return }
            logger.error(
                "Could not update badge: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    static func badgeCount(
        from snapshot: UsageSnapshot,
        at date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int? {
        guard snapshot.storedDailyLimit > 0 else { return nil }

        let estimate = UsageEstimator.estimate(
            from: snapshot,
            at: date,
            calendar: calendar
        )
        guard estimate.isAvailable else { return nil }

        return max(0, Int(estimate.remainingTime / 60))
    }
}
