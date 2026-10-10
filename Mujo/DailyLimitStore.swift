//
//  DailyLimitStore.swift
//  Mujo
//

import Foundation

@MainActor
final class DailyLimitStore {
    private let sharedDefaults: UserDefaults?
    let migratedLimit: TimeInterval?

    init(sharedDefaults: UserDefaults?) {
        self.sharedDefaults = sharedDefaults
        let key = AppConfiguration.DefaultsKey.dailyLimit
        let storedObject = sharedDefaults?.object(forKey: key)
        let storedLimit = sharedDefaults?.double(forKey: key) ?? 0
        let normalizedLimit = AppConfiguration.DailyLimit.normalizedLimit(
            storedLimit
        )
        if storedObject == nil {
            // The monitor extension needs the selected limit even before the
            // person changes the default value on the dial.
            sharedDefaults?.set(normalizedLimit, forKey: key)
            migratedLimit = nil
        } else if storedLimit != normalizedLimit {
            sharedDefaults?.set(normalizedLimit, forKey: key)
            migratedLimit = normalizedLimit
        } else {
            migratedLimit = nil
        }
    }

    var currentLimit: TimeInterval {
        let storedValue = sharedDefaults?.double(
            forKey: AppConfiguration.DefaultsKey.dailyLimit
        ) ?? 0
        return AppConfiguration.DailyLimit.normalizedLimit(storedValue)
    }

    @discardableResult
    func save(_ limit: TimeInterval) -> Bool {
        guard limit.isFinite, limit > 0 else { return false }
        guard let sharedDefaults else { return false }
        let normalizedLimit = AppConfiguration.DailyLimit.normalizedLimit(limit)
        guard normalizedLimit != currentLimit else { return false }

        sharedDefaults.set(
            normalizedLimit,
            forKey: AppConfiguration.DefaultsKey.dailyLimit
        )
        return true
    }
}
