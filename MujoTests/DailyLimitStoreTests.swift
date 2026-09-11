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
    @Test("Missing and invalid values use the two-hour default")
    func usesDefaultLimit() {
        withStore { store, defaults in
            #expect(MujoShared.defaultDailyLimit == 2 * 60 * 60)
            #expect(store.currentLimit == MujoShared.defaultDailyLimit)

            defaults.set(
                -60,
                forKey: MujoShared.DefaultsKey.dailyLimit
            )
            #expect(store.currentLimit == MujoShared.defaultDailyLimit)
        }
    }

    @Test("A new valid limit is persisted only once")
    func savesChangedLimit() {
        withStore { store, defaults in
            let newLimit: TimeInterval = 90 * 60

            #expect(store.save(newLimit))
            #expect(store.currentLimit == newLimit)
            #expect(
                defaults.double(forKey: MujoShared.DefaultsKey.dailyLimit)
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
            #expect(
                defaults.object(forKey: MujoShared.DefaultsKey.dailyLimit)
                    == nil
            )
        }
    }

    @Test("A stale preview is removed during initialization")
    func removesStalePreview() {
        withStore(
            configure: { defaults in
                defaults.set(
                    60 * 60,
                    forKey: MujoShared.DefaultsKey.previewDailyLimit
                )
            },
            assertions: { _, defaults in
                #expect(
                    defaults.object(
                        forKey: MujoShared.DefaultsKey.previewDailyLimit
                    ) == nil
                )
            }
        )
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
