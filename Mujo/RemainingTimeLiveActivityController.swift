//
//  RemainingTimeLiveActivityController.swift
//  Mujo
//
//  Created by Aikari Studio on 16/09/2026.
//

import ActivityKit
import Foundation

@MainActor
enum RemainingTimeLiveActivityController {
    @discardableResult
    static func start(
        remainingMinutes: Int,
        limitMinutes: Int,
        updatedAt: Date
    ) async throws -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return false
        }

        let limit = AppConfiguration.DailyLimit.normalizedMinutes(limitMinutes)
        let state = RemainingTimeActivityAttributes.ContentState(
            remainingMinutes: min(max(0, remainingMinutes), limit),
            updatedAt: updatedAt
        )
        let content = ActivityContent(
            state: state,
            staleDate: updatedAt.addingTimeInterval(2 * 60)
        )

        if let existing = Activity<RemainingTimeActivityAttributes>
            .activities.first(where: { $0.activityState == .active }) {
            if existing.attributes.limitMinutes == limit {
                await existing.update(content)
                return true
            }

            await existing.end(nil, dismissalPolicy: .immediate)
        }

        _ = try Activity<RemainingTimeActivityAttributes>.request(
            attributes: RemainingTimeActivityAttributes(limitMinutes: limit),
            content: content,
            pushType: nil
        )
        return true
    }
}
