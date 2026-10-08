import Foundation
import Testing
@testable import Mujo

@Suite("App Group entitlements")
struct AppGroupEntitlementTests {
    @Test("Every process uses the same App Group")
    func allTargetsShareAppGroup() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let entitlementPaths = [
            "Mujo/Mujo.entitlements",
            "ActivityMonitor/ActivityMonitor.entitlements",
            "CountdownWidgetExtension.entitlements",
            "ScreenTimeReport/ScreenTimeReport.entitlements"
        ]

        for path in entitlementPaths {
            let data = try Data(contentsOf: repository.appending(path: path))
            let plist = try #require(
                PropertyListSerialization.propertyList(
                    from: data,
                    format: nil
                ) as? [String: Any]
            )
            let groups = try #require(
                plist["com.apple.security.application-groups"] as? [String]
            )
            #expect(groups == [AppConfiguration.appGroupIdentifier])
        }
    }
}
