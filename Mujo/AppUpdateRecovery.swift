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

    var lastRecoveredBuildNumber: Int? {
        guard let recoveredBuild = defaults.string(forKey: Self.recoveredBuildKey),
              recoveredBuild.hasSuffix(")"),
              let buildStart = recoveredBuild.lastIndex(of: "(")
        else { return nil }

        let buildNumber = recoveredBuild.dropLast()[recoveredBuild.index(after: buildStart)...]
        return Int(buildNumber)
    }

    func markCompleted() {
        guard let currentBuild else { return }
        defaults.set(currentBuild, forKey: Self.recoveredBuildKey)
    }
}
