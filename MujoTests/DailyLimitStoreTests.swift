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
            #expect(AppConfiguration.defaultDailyLimit == 2 * 60 * 60)
            #expect(store.currentLimit == AppConfiguration.defaultDailyLimit)

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
            #expect(
                defaults.object(forKey: AppConfiguration.DefaultsKey.dailyLimit)
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
                    forKey: AppConfiguration.DefaultsKey.previewDailyLimit
                )
            },
            assertions: { _, defaults in
                #expect(
                    defaults.object(
                        forKey: AppConfiguration.DefaultsKey.previewDailyLimit
                    ) == nil
                )
            }
        )
    }

    @Test("Rapid previews persist only the newest value")
    func coalescesPreviewWrites() async {
        await withSuspendedPreviewQueue { store, defaults in
            store.preview(minutes: 30)
            store.preview(minutes: 60)
            store.preview(minutes: 90)

            return {
                #expect(
                    defaults.double(
                        forKey: AppConfiguration.DefaultsKey.previewDailyLimit
                    ) == 90 * 60
                )
            }
        }
    }

    @Test("Preview values are clamped to at least one minute")
    func clampsPreviewToOneMinute() async {
        await withSuspendedPreviewQueue { store, defaults in
            store.preview(minutes: 0)

            return {
                #expect(
                    defaults.double(
                        forKey: AppConfiguration.DefaultsKey.previewDailyLimit
                    ) == 60
                )
            }
        }
    }

    @Test("Clearing preview cancels its pending write")
    func clearsPendingPreview() async {
        await withSuspendedPreviewQueue { store, defaults in
            defaults.set(
                30 * 60,
                forKey: AppConfiguration.DefaultsKey.previewDailyLimit
            )
            store.preview(minutes: 90)
            store.clearPreview()

            return {
                #expect(
                    defaults.object(
                        forKey: AppConfiguration.DefaultsKey.previewDailyLimit
                    ) == nil
                )
            }
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

    private func withSuspendedPreviewQueue(
        scheduleWrites: (
            DailyLimitStore,
            UserDefaults
        ) -> (() -> Void)
    ) async {
        let suiteName = "AikariStudio.MujoTests.DailyLimitPreview."
            + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults")
            return
        }

        defaults.removePersistentDomain(forName: suiteName)
        let queue = DispatchQueue(
            label: suiteName,
            qos: .userInitiated
        )
        let store = DailyLimitStore(
            sharedDefaults: defaults,
            previewSuiteName: suiteName,
            previewWriteQueue: queue,
            previewWriteDelay: .milliseconds(0)
        )

        queue.suspend()
        var queueIsSuspended = true
        defer {
            if queueIsSuspended {
                queue.resume()
            }
            defaults.removePersistentDomain(forName: suiteName)
        }

        let assertions = scheduleWrites(store, defaults)
        try? await Task.sleep(for: .milliseconds(5))
        queue.resume()
        queueIsSuspended = false
        await drain(queue)
        assertions()
    }

    private func drain(_ queue: DispatchQueue) async {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume()
            }
        }
    }
}
