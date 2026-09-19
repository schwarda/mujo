//
//  AppUpdateRecovery.swift
//  Mujo
//

import Foundation

struct AppUpdateRecovery {
    private static let recoveredBuildKey = "mujo.lastRecoveredBuild"

    private let defaults: UserDefaults
    private let currentBuild: String?

    init(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main
    ) {
        self.defaults = defaults

        guard let version = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String,
              let build = bundle.object(
                  forInfoDictionaryKey: "CFBundleVersion"
              ) as? String
        else {
            currentBuild = nil
            return
        }

        currentBuild = "\(version) (\(build))"
    }

    var isRequired: Bool {
        guard let currentBuild else { return false }
        return defaults.string(forKey: Self.recoveredBuildKey) != currentBuild
    }

    func markCompleted() {
        guard let currentBuild else { return }
        defaults.set(currentBuild, forKey: Self.recoveredBuildKey)
    }
}
