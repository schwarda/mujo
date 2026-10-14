import Testing
@testable import Mujo

@Suite("App Info metadata")
struct AppInfoMetadataTests {
    @Test("Version and build are formatted for display")
    func formatsVersionAndBuild() {
        let metadata = AppInfoMetadata(infoDictionary: [
            "CFBundleShortVersionString": "1.2",
            "CFBundleVersion": "45",
        ])

        #expect(metadata.versionAndBuild == "Version 1.2 (45)")
    }

    @Test("Missing bundle values use a stable fallback")
    func fallsBackWhenBundleValuesAreMissing() {
        let metadata = AppInfoMetadata(infoDictionary: [:])

        #expect(metadata.versionAndBuild == "Version —")
    }
}
