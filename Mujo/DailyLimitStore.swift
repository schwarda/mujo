//
//  DailyLimitStore.swift
//  Mujo
//

import Foundation

@MainActor
final class DailyLimitStore {
    private let sharedDefaults: UserDefaults
    private let previewSuiteName: String
    private let previewWriteQueue: DispatchQueue
    private let previewWriteDelay: DispatchTimeInterval
    private var pendingPreviewWrite: DispatchWorkItem?
    let migratedLimit: TimeInterval?

    init(
        sharedDefaults: UserDefaults,
        previewSuiteName: String = AppConfiguration.appGroupIdentifier,
        previewWriteQueue: DispatchQueue = DispatchQueue(
            label: "AikariStudio.Mujo.daily-limit-preview",
            qos: .userInitiated
        ),
        previewWriteDelay: DispatchTimeInterval = .milliseconds(50)
    ) {
        self.sharedDefaults = sharedDefaults
        self.previewSuiteName = previewSuiteName
        self.previewWriteQueue = previewWriteQueue
        self.previewWriteDelay = previewWriteDelay
        let key = AppConfiguration.DefaultsKey.dailyLimit
        let storedObject = sharedDefaults.object(forKey: key)
        let storedLimit = sharedDefaults.double(forKey: key)
        let normalizedLimit = AppConfiguration.DailyLimit.normalizedLimit(
            storedLimit
        )
        if storedObject == nil {
            // The monitor extension needs the selected limit even before the
            // person changes the default value on the dial.
            sharedDefaults.set(normalizedLimit, forKey: key)
            migratedLimit = nil
        } else if storedLimit != normalizedLimit {
            sharedDefaults.set(normalizedLimit, forKey: key)
            migratedLimit = normalizedLimit
        } else {
            migratedLimit = nil
        }
        sharedDefaults.removeObject(
            forKey: AppConfiguration.DefaultsKey.previewDailyLimit
        )
    }

    var currentLimit: TimeInterval {
        let storedValue = sharedDefaults.double(
            forKey: AppConfiguration.DefaultsKey.dailyLimit
        )
        return AppConfiguration.DailyLimit.normalizedLimit(storedValue)
    }

    @discardableResult
    func save(_ limit: TimeInterval) -> Bool {
        guard limit.isFinite, limit > 0 else { return false }
        let normalizedLimit = AppConfiguration.DailyLimit.normalizedLimit(limit)
        guard normalizedLimit != currentLimit else { return false }

        sharedDefaults.set(
            normalizedLimit,
            forKey: AppConfiguration.DefaultsKey.dailyLimit
        )
        return true
    }

    func preview(minutes: Int) {
        let safeMinutes = AppConfiguration.DailyLimit.normalizedMinutes(minutes)
        let previewLimit = TimeInterval(safeMinutes * 60)
        let suiteName = previewSuiteName
        let key = AppConfiguration.DefaultsKey.previewDailyLimit
        let workItem = DispatchWorkItem {
            UserDefaults(suiteName: suiteName)?.set(
                previewLimit,
                forKey: key
            )
        }

        pendingPreviewWrite?.cancel()
        pendingPreviewWrite = workItem
        previewWriteQueue.asyncAfter(
            deadline: .now() + previewWriteDelay,
            execute: workItem
        )
    }

    func clearPreview() {
        pendingPreviewWrite?.cancel()
        pendingPreviewWrite = nil

        let suiteName = previewSuiteName
        let key = AppConfiguration.DefaultsKey.previewDailyLimit
        previewWriteQueue.async {
            UserDefaults(suiteName: suiteName)?.removeObject(forKey: key)
        }
    }
}
