//
//  DailyLimitStoreTests.swift
//  MujoTests
//

import Foundation
import Testing
@testable import Mujo

@Suite("Daily limit storage")
@MainActor
struct DailyLimitStoreTests {
    @Test("Unavailable shared storage never falls back to local preferences")
    @MainActor
    func unavailableSharedStorageDoesNotPersist() {
        let store = DailyLimitStore(sharedDefaults: nil)

        #expect(store.currentLimit == AppConfiguration.defaultDailyLimit)
        #expect(!store.save(2 * 60 * 60))
        #expect(store.currentLimit == AppConfiguration.defaultDailyLimit)
    }

    @Test("Missing and invalid values use the two-hour default")
    func usesDefaultLimit() {
        withStore { store, defaults in
            #expect(AppConfiguration.defaultDailyLimit == 2 * 60 * 60)
            #expect(store.currentLimit == AppConfiguration.defaultDailyLimit)
            #expect(defaults.double(
                forKey: AppConfiguration.DefaultsKey.dailyLimit
            ) == AppConfiguration.defaultDailyLimit)

            defaults.set(
                -60,
                forKey: AppConfiguration.DefaultsKey.dailyLimit
            )
            #expect(store.currentLimit == AppConfiguration.defaultDailyLimit)
        }
    }

    @Test("A new valid limit is persisted only once")
    func savesChangedLimit() {
        withStore { store, defaults in
            let newLimit: TimeInterval = 90 * 60

            #expect(store.save(newLimit))
            #expect(store.currentLimit == newLimit)
            #expect(
                defaults.double(forKey: AppConfiguration.DefaultsKey.dailyLimit)
                    == newLimit
            )
            #expect(!store.save(newLimit))
        }
    }

    @Test("Invalid limits are not persisted")
    func rejectsInvalidLimits() {
        withStore { store, defaults in
            #expect(!store.save(0))
            #expect(!store.save(-60))
            #expect(store.currentLimit == AppConfiguration.defaultDailyLimit)
            #expect(defaults.double(
                forKey: AppConfiguration.DefaultsKey.dailyLimit
            ) == AppConfiguration.defaultDailyLimit)
        }
    }

    private func withStore(
        configure: (UserDefaults) -> Void = { _ in },
        assertions: (DailyLimitStore, UserDefaults) -> Void
    ) {
        let suiteName = "AikariStudio.MujoTests.DailyLimitStore."
            + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults")
            return
        }

        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        configure(defaults)
        let store = DailyLimitStore(sharedDefaults: defaults)
        assertions(store, defaults)
    }

}
