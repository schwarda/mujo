import Foundation
import SwiftUI
import UIKit

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
            OnboardingBackground()

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
                                        .foregroundStyle(Color.primary)
                                } label: {
                                    Label {
                                        Text(link.title)
                                            .foregroundStyle(Color.primary)
                                    } icon: {
                                        Image(systemName: link.systemImage)
                                            .foregroundStyle(.tint)
                                    }
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
                                .foregroundStyle(Color.primary)
                            
                            if let sourceURL = URL(
                                string: "https://www.magnific.com/free-vector/mobile_418125913.htm"
                            ) {
                                Link("Image by user15245033 on Magnific", destination: sourceURL)
                                    .foregroundStyle(Color.accentColor)
                                    .accessibilityIdentifier("artwork-source-link")
                            }
                        }
                    } label: {
                        Label {
                            Text("Credits")
                                .foregroundStyle(Color.primary)
                        } icon: {
                            Image(systemName: "person.2")
                                .foregroundStyle(.tint)
                        }
                    }
                    .tint(.accentColor)
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
        .background { PinkNavigationBackIndicator() }
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

// Style the native back indicator on this destination's navigation item,
// preserving the system back button, its menu and interactive pop gesture.
struct PinkNavigationBackIndicator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {
        guard controller.viewIfLoaded?.window != nil else { return }
        controller.applyAppearance()
    }

    final class Controller: UIViewController {
        private var isVisible = false

        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            isVisible = true
            applyAppearance()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyAppearance()
        }

        override func viewWillDisappear(_ animated: Bool) {
            isVisible = false
            super.viewWillDisappear(animated)
        }

        func applyAppearance() {
            guard isVisible, let navigationController,
                  let item = navigationController.topViewController?.navigationItem
            else { return }
            let bar = navigationController.navigationBar
            let color = UIColor(Color.accentColor)

            // The system back button belongs to the preceding navigation item.
            // Tint that item as well as the indicator appearance on the destination.
            if let previous = navigationController.viewControllers.dropLast().last?.navigationItem {
                if previous.backBarButtonItem == nil {
                    previous.backBarButtonItem = UIBarButtonItem(
                        title: previous.backButtonTitle ?? previous.title,
                        style: .plain,
                        target: nil,
                        action: nil
                    )
                }
                previous.backBarButtonItem?.tintColor = color
            }

            func tinted(_ source: UINavigationBarAppearance) -> UINavigationBarAppearance {
                let appearance = source.copy() as! UINavigationBarAppearance
                appearance.setBackIndicatorImage(
                    source.backIndicatorImage.withTintColor(color, renderingMode: .alwaysOriginal),
                    transitionMaskImage: source.backIndicatorTransitionMaskImage
                )
                return appearance
            }

            item.standardAppearance = tinted(item.standardAppearance ?? bar.standardAppearance)
            item.scrollEdgeAppearance = tinted(
                item.scrollEdgeAppearance ?? bar.scrollEdgeAppearance ?? bar.standardAppearance
            )
            item.compactAppearance = tinted(
                item.compactAppearance ?? bar.compactAppearance ?? bar.standardAppearance
            )
            item.compactScrollEdgeAppearance = tinted(
                item.compactScrollEdgeAppearance ?? bar.compactScrollEdgeAppearance
                    ?? bar.standardAppearance
            )
        }
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
