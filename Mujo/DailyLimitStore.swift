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
        sharedDefaults.removeObject(
            forKey: AppConfiguration.DefaultsKey.previewDailyLimit
        )
    }

    var currentLimit: TimeInterval {
        let storedValue = sharedDefaults.double(
            forKey: AppConfiguration.DefaultsKey.dailyLimit
        )
        return storedValue > 0
            ? storedValue
            : AppConfiguration.defaultDailyLimit
    }

    @discardableResult
    func save(_ limit: TimeInterval) -> Bool {
        guard limit > 0, limit != currentLimit else { return false }

        sharedDefaults.set(
            limit,
            forKey: AppConfiguration.DefaultsKey.dailyLimit
        )
        return true
    }

    func preview(minutes: Int) {
        let safeMinutes = max(1, minutes)
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
