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
            forKey: MujoShared.DefaultsKey.activityReportRequestID
        )
        sharedDefaults.removeObject(
            forKey: MujoShared.DefaultsKey.readyActivityReportRequestID
        )
        return requestID
    }

    func waitUntilReady(
        requestID: String,
        timeout: Duration = .seconds(2)
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while !Task.isCancelled && clock.now < deadline {
            let readyRequestID = sharedDefaults.string(
                forKey: MujoShared.DefaultsKey.readyActivityReportRequestID
            )
            if readyRequestID == requestID {
                return
            }

            try? await Task.sleep(for: .milliseconds(25))
        }
    }
}
