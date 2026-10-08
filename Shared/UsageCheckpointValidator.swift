import Foundation

nonisolated enum UsageCheckpointRejectionReason: String, Equatable, Sendable {
    case invalidThreshold
    case beforeMeasurementStart
    case exceedsElapsedMeasurementTime
}

nonisolated enum UsageCheckpointDecision: Equatable, Sendable {
    case accept
    case reject(UsageCheckpointRejectionReason)
}

enum UsageCheckpointValidator {
    // Device Activity callbacks can be delivered a little after the activity
    // happened. The tolerance protects valid callbacks around clock boundaries
    // without allowing an hours-long impossible jump.
    static let deliveryTolerance: TimeInterval = 2 * 60

    static func decision(
        reachedSeconds: TimeInterval,
        monitoringStartedAt: TimeInterval,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent,
        tolerance: TimeInterval = deliveryTolerance
    ) -> UsageCheckpointDecision {
        guard reachedSeconds.isFinite, reachedSeconds > 0 else {
            return .reject(.invalidThreshold)
        }

        let dayStart = calendar.startOfDay(for: now).timeIntervalSince1970
        let measurementStart: TimeInterval

        if monitoringStartedAt > 0 {
            guard monitoringStartedAt <= now.timeIntervalSince1970 + tolerance else {
                return .reject(.beforeMeasurementStart)
            }
            measurementStart = max(dayStart, monitoringStartedAt)
        } else {
            measurementStart = dayStart
        }

        let elapsed = max(0, now.timeIntervalSince1970 - measurementStart)
        guard reachedSeconds <= elapsed + max(0, tolerance) else {
            return .reject(.exceedsElapsedMeasurementTime)
        }

        return .accept
    }
}
