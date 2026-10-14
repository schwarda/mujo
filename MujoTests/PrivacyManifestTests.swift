import Foundation
import Testing

@Suite("Privacy manifests")
struct PrivacyManifestTests {
    @Test("Every executable declares only its approved UserDefaults reasons")
    func everyExecutableDeclaresUserDefaultsReasons() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let expectedReasonsByPath: [String: Set<String>] = [
            "Mujo/PrivacyInfo.xcprivacy": ["CA92.1", "1C8F.1"],
            "ActivityMonitor/PrivacyInfo.xcprivacy": ["1C8F.1"],
            "CountdownWidget/PrivacyInfo.xcprivacy": ["1C8F.1"],
            "ScreenTimeReport/PrivacyInfo.xcprivacy": ["1C8F.1"],
        ]

        for (path, expectedReasons) in expectedReasonsByPath {
            let manifest = try loadManifest(
                at: repository.appending(path: path)
            )
            #expect(manifest["NSPrivacyTracking"] as? Bool == false)
            #expect(
                manifest["NSPrivacyTrackingDomains"] as? [String] == []
            )
            let collectedDataTypes = try #require(
                manifest["NSPrivacyCollectedDataTypes"]
                    as? [[String: Any]]
            )
            #expect(collectedDataTypes.isEmpty)

            let accessedTypes = try #require(
                manifest["NSPrivacyAccessedAPITypes"]
                    as? [[String: Any]]
            )
            #expect(accessedTypes.count == 1)
            let userDefaults = try #require(accessedTypes.first)
            #expect(
                userDefaults["NSPrivacyAccessedAPIType"] as? String
                    == "NSPrivacyAccessedAPICategoryUserDefaults"
            )
            let reasons = try #require(
                userDefaults["NSPrivacyAccessedAPITypeReasons"] as? [String]
            )
            #expect(Set(reasons) == expectedReasons)
        }
    }

    private func loadManifest(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(
            PropertyListSerialization.propertyList(
                from: data,
                format: nil
            ) as? [String: Any]
        )
    }
}
