//
//  RemainingTimeActivityAttributes.swift
//  Mujo
//
//  Created by Aikari Studio on 16/09/2026.
//

import ActivityKit
import Foundation

nonisolated struct RemainingTimeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let remainingMinutes: Int
        let updatedAt: Date
    }

    let limitMinutes: Int
}
