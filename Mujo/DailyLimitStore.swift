//
//  DailyLimitStore.swift
//  Mujo
//

import Foundation

@MainActor
final class DailyLimitStore {
    private let sharedDefaults: UserDefaults
    private let previewWriteQueue = DispatchQueue(
        label: "AikariStudio.Mujo.daily-limit-preview",
        qos: .userInitiated
    )
    private var pendingPreviewWrite: DispatchWorkItem?

    init(sharedDefaults: UserDefaults) {
        self.sharedDefaults = sharedDefaults
        sharedDefaults.removeObject(
            forKey: MujoShared.DefaultsKey.previewDailyLimit
        )
    }

    var currentLimit: TimeInterval {
        let storedValue = sharedDefaults.double(
            forKey: MujoShared.DefaultsKey.dailyLimit
        )
        return storedValue > 0
            ? storedValue
            : MujoShared.defaultDailyLimit
    }

    @discardableResult
    func save(_ limit: TimeInterval) -> Bool {
        guard limit > 0, limit != currentLimit else { return false }

        sharedDefaults.set(
            limit,
            forKey: MujoShared.DefaultsKey.dailyLimit
        )
        return true
    }

    func preview(minutes: Int) {
        let safeMinutes = max(1, minutes)
        let previewLimit = TimeInterval(safeMinutes * 60)
        let suiteName = MujoShared.appGroupIdentifier
        let key = MujoShared.DefaultsKey.previewDailyLimit
        let workItem = DispatchWorkItem {
            UserDefaults(suiteName: suiteName)?.set(
                previewLimit,
                forKey: key
            )
        }

        pendingPreviewWrite?.cancel()
        pendingPreviewWrite = workItem
        previewWriteQueue.asyncAfter(
            deadline: .now() + .milliseconds(50),
            execute: workItem
        )
    }

    func clearPreview() {
        pendingPreviewWrite?.cancel()
        pendingPreviewWrite = nil

        let suiteName = MujoShared.appGroupIdentifier
        let key = MujoShared.DefaultsKey.previewDailyLimit
        previewWriteQueue.async {
            UserDefaults(suiteName: suiteName)?.removeObject(forKey: key)
        }
    }
}
