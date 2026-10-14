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
    private struct PlaceholderLink: Identifiable {
        let title: String
        let systemImage: String

        var id: String { title }
    }

    private static let placeholderItems = [
        PlaceholderLink(
            title: "Privacy Policy",
            systemImage: "hand.raised"
        ),
        PlaceholderLink(
            title: "Support",
            systemImage: "questionmark.circle"
        ),
        PlaceholderLink(
            title: "Terms of Use",
            systemImage: "doc.text"
        ),
    ]

    @Environment(\.dismiss) private var dismiss
    private let metadata: AppInfoMetadata

    init(metadata: AppInfoMetadata = AppInfoMetadata()) {
        self.metadata = metadata
    }

    var body: some View {
        ZStack {
            SakuraBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                appIdentity

                placeholderLinksSection
                    .padding(.top, 60)

                Text(metadata.copyright)
                    .font(MujoTheme.italicFont(
                        size: 14,
                        relativeTo: .footnote
                    ))
                    .foregroundStyle(
                        MujoTheme.glassAccent.opacity(
                            MujoTheme.secondaryTextOpacity
                        )
                    )
                    .padding(.top, 28)
//                    .padding(.bottom, 34)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)

            backButtonOverlay
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var backButtonOverlay: some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.clear.interactive(), in: .circle)
                .foregroundStyle(.tint)
                .accessibilityLabel("Back")

                Spacer()
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var appIdentity: some View {
        VStack(spacing: 10) {
            Image("LaunchLogo")
                .frame(width: 128, height: 128)
                .accessibilityHidden(true)

            Text("Mujø")
                .font(MujoTheme.boldFont(
                    size: 42,
                    relativeTo: .largeTitle
                ))
                .foregroundStyle(.tint)

            Text(metadata.versionAndBuild)
                .font(MujoTheme.mediumFont(
                    size: 15,
                    relativeTo: .subheadline
                ))
                .monospacedDigit()
                .foregroundStyle(
                    MujoTheme.glassAccent.opacity(
                        MujoTheme.secondaryTextOpacity
                    )
                )
        }
        .accessibilityElement(children: .combine)
    }

    private var placeholderLinksSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(Self.placeholderItems.enumerated()), id: \.element.id) {
                index, link in
                HStack(spacing: 14) {
                    Image(systemName: link.systemImage)
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 24)

                    Text(link.title)
                        .font(MujoTheme.mediumFont(
                            size: OnboardingTypography.systemUI,
                            relativeTo: .body
                        ))

                    Spacer(minLength: 12)

                    Text("Coming soon")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(
                            MujoTheme.glassAccent.opacity(
                                MujoTheme.secondaryTextOpacity
                            )
                        )
                }
                .foregroundStyle(MujoTheme.glassAccent)
                .frame(minHeight: 56)
                .padding(.horizontal, 18)
                .accessibilityElement(children: .combine)

                if index < Self.placeholderItems.count - 1 {
                    Divider()
                        .overlay(
                            MujoTheme.glassAccent.opacity(0.14)
                        )
                        .padding(.leading, 56)
                }
            }
        }
        .glassEffect(.clear, in: .rect(cornerRadius: 24))
    }
}

#Preview("App Info") {
    AppInfoScreen(metadata: AppInfoMetadata(infoDictionary: [
        "CFBundleShortVersionString": "1.0",
        "CFBundleVersion": "6",
        "NSHumanReadableCopyright": "© 2026 Aikari Studio",
    ]))
}
