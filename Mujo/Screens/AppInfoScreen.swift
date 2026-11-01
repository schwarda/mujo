import Foundation
import SwiftUI

struct AppInfoMetadata {
    let version: String?
    let build: String?
    let copyright: String

    init(infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        version = infoDictionary["CFBundleShortVersionString"] as? String
        build = infoDictionary["CFBundleVersion"] as? String
        copyright = infoDictionary["NSHumanReadableCopyright"] as? String
            ?? "© 2026 Aikari Studio"
    }

    var versionAndBuild: String {
        guard let version else { return "Version —" }
        guard let build else { return "Version \(version)" }
        return "Version \(version) (\(build))"
    }
}

struct AppInfoScreen: View {
    private struct InformationLink: Identifiable {
        let title: String
        let systemImage: String
        let urlString: String

        var id: String { title }
    }

    private static let informationItems = [
        InformationLink(
            title: "Privacy Policy",
            systemImage: "hand.raised",
            urlString: "https://aikaristudio.com/privacy/"
        ),
        InformationLink(
            title: "Support",
            systemImage: "questionmark.circle",
            urlString: "https://aikaristudio.com/support/"
        ),
        InformationLink(
            title: "Terms of Use",
            systemImage: "doc.text",
            urlString: "https://aikaristudio.com/terms/"
        ),
    ]

    @State private var isCreditsExpanded = false
    private let metadata: AppInfoMetadata

    init(metadata: AppInfoMetadata = AppInfoMetadata()) {
        self.metadata = metadata
    }

    var body: some View {
        ZStack {
            SakuraBackground().ignoresSafeArea()

            List {
                Section {
                    appIdentity
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    ForEach(Self.informationItems) { link in
                        if let destination = URL(string: link.urlString) {
                            Link(destination: destination) {
                                LabeledContent {
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(.secondary)
                                } label: {
                                    Label(
                                        link.title,
                                        systemImage: link.systemImage
                                    )
                                }
                            }
                        }
                    }
                } header: {
                    Text("Information")
                }

                Section {
                    DisclosureGroup(isExpanded: $isCreditsExpanded) {
                        VStack(alignment: .leading) {
                            Text("Sakura petal artwork")
                            
                            if let sourceURL = URL(
                                string: "https://www.magnific.com/free-vector/mobile_418125913.htm"
                            ) {
                                Link("Image by user15245033 on Magnific", destination: sourceURL)
                                    .accessibilityIdentifier("artwork-source-link")
                            }
                        }
                    } label: {
                        Label("Credits", systemImage: "person.2")
                    }
                    .accessibilityIdentifier("credits-disclosure")
                } footer: {
                    Text(metadata.copyright)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .tint(.accentColor)
        .navigationTitle("App Info")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar(.visible, for: .navigationBar)
    }

    private var appIdentity: some View {
        VStack(spacing: 10) {
            Image("LaunchLogo")
                .frame(width: 128, height: 128)
                .accessibilityHidden(true)

            Text("Mujø")
                .font(.largeTitle.bold())
                .foregroundStyle(.tint)

            Text(metadata.versionAndBuild)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

#Preview("App Info") {
    NavigationStack {
        AppInfoScreen(metadata: AppInfoMetadata(infoDictionary: [
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "6",
            "NSHumanReadableCopyright": "© 2026 Aikari Studio",
        ]))
    }
}
