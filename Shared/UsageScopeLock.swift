import CoreFoundation
import Darwin
import Foundation
import OSLog

/// Serializes scope changes in the app with checkpoint commits in ActivityMonitor.
nonisolated enum UsageScopeLock {
    private static let logger = Logger(
        subsystem: "AikariStudio.Mujo",
        category: "UsageScopeStorage"
    )

    enum Unavailable: LocalizedError {
        case missingContainer
        case openFailed(Int32)
        case lockFailed(Int32)
        case preferencesReadFailed

        var errorDescription: String? {
            String(localized: "Screen Time storage is unavailable. Try again.")
        }
    }

    static func withLock<Value>(
        _ action: () throws -> Value
    ) throws -> Value {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConfiguration.appGroupIdentifier
        ) else { throw Unavailable.missingContainer }

        let lockURL = container.appendingPathComponent("usage-scope.lock")
        let descriptor = open(lockURL.path, O_CREAT | O_CLOEXEC | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw Unavailable.openFailed(errno) }
        defer { close(descriptor) }

        while flock(descriptor, LOCK_EX) == -1 {
            let code = errno
            guard code == EINTR else { throw Unavailable.lockFailed(code) }
        }
        defer { flock(descriptor, LOCK_UN) }

        // Synchronize the exact App Group domain used by the defaults suite.
        guard synchronizePreferences() else { throw Unavailable.preferencesReadFailed }
        defer {
            if !synchronizePreferences() {
                logger.error("Could not flush App Group preferences before unlocking")
            }
        }
        return try action()
    }

    private static func synchronizePreferences() -> Bool {
        CFPreferencesSynchronize(
            AppConfiguration.appGroupIdentifier as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
    }
}
