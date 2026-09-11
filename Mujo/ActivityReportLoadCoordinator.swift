//
//  ActivityReportLoadCoordinator.swift
//  Mujo
//

import Foundation

@MainActor
final class ActivityReportLoadCoordinator {
    private let sharedDefaults: UserDefaults

    init(sharedDefaults: UserDefaults) {
        self.sharedDefaults = sharedDefaults
    }

    func beginLoading() -> String {
        let requestID = UUID().uuidString
        sharedDefaults.set(
            requestID,
            forKey: AppConfiguration.DefaultsKey.activityReportRequestID
        )
        sharedDefaults.removeObject(
            forKey: AppConfiguration.DefaultsKey.readyActivityReportRequestID
        )
        return requestID
    }

    @discardableResult
    func waitUntilReady(
        requestID: String,
        timeout: Duration = .seconds(2)
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while !Task.isCancelled && clock.now < deadline {
            let readyRequestID = sharedDefaults.string(
                forKey: AppConfiguration.DefaultsKey.readyActivityReportRequestID
            )
            if readyRequestID == requestID {
                return true
            }

            try? await Task.sleep(for: .milliseconds(25))
        }

        return false
    }
}
