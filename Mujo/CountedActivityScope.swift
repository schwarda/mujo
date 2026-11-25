import FamilyControls
import Foundation

nonisolated struct CountedActivityScope {
    enum StorageError: LocalizedError {
        case invalidScope
        case authorizationChanged

        var errorDescription: String? {
            switch self {
            case .invalidScope:
                String(localized: "Your saved activity selection couldn’t be read. Open Counted Apps and save a new selection.")
            case .authorizationChanged:
                String(localized: "Screen Time access changed. Open Counted Apps and save a new selection.")
            }
        }
    }

    let selection: FamilyActivitySelection
    let activityName: String

    static func load(from defaults: UserDefaults?) throws -> Self {
        guard let defaults else { throw StorageError.invalidScope }
        if AppConfiguration.Monitoring.scopeNeedsReselection(in: defaults) {
            throw StorageError.authorizationChanged
        }
        guard let activityName = AppConfiguration.Monitoring
            .activeUsageActivityName(in: defaults) else { throw StorageError.invalidScope }
        guard activityName != AppConfiguration.Monitoring.usageActivityName else {
            return Self(selection: FamilyActivitySelection(), activityName: activityName)
        }
        guard let data = defaults
            .dictionary(forKey: AppConfiguration.DefaultsKey.countedActivityScope)?[
                AppConfiguration.Monitoring.scopeSelectionKey
            ] as? Data,
              let selection = try? decodeSelection(data)
        else { throw StorageError.invalidScope }
        return Self(selection: selection, activityName: activityName)
    }

    // Call while holding the scope lock, before publishing authorization loss.
    static func recordAuthorizationLoss(in defaults: UserDefaults) -> Bool {
        defaults.set(
            UUID().uuidString,
            forKey: AppConfiguration.DefaultsKey.countedActivityAuthorizationRevision
        )
        guard let saved = try? load(from: defaults), !saved.selection.countsAllActivity else {
            return false
        }
        defaults.set(
            [AppConfiguration.Monitoring.scopeNeedsReselectionKey: true],
            forKey: AppConfiguration.DefaultsKey.countedActivityScope
        )
        return true
    }

    static func encodeSelection(_ selection: FamilyActivitySelection) throws -> Data {
        try PropertyListEncoder().encode(selection)
    }

    static func decodeSelection(_ data: Data) throws -> FamilyActivitySelection {
        try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    }
}

extension FamilyActivitySelection {
    nonisolated var countsAllActivity: Bool {
        applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty
    }

    nonisolated func countsSameActivity(as other: Self) -> Bool {
        applicationTokens == other.applicationTokens
            && categoryTokens == other.categoryTokens
            && webDomainTokens == other.webDomainTokens
    }
}
