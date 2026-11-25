import SwiftUI
import UIKit

struct AboutScreen: View {
    private static let authorName: String? = "Dávid Schwartz"
    // Brand marks from Simple Icons.
    private static let socialLinks: [(title: LocalizedStringKey, icon: String, urlString: String)] = [
        ("Instagram", "SocialInstagram", "https://www.instagram.com/aikari_studio/"),
        ("TikTok", "SocialTikTok", "https://www.tiktok.com/@aikari_studio"),
        ("X", "SocialX", "https://x.com/AikariStudio"),
        ("YouTube", "SocialYouTube", "https://www.youtube.com/@aikari_studio"),
        ("Facebook", "SocialFacebook", "https://www.facebook.com/profile.php?id=61594876967138"),
    ]

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @State private var isShowingFeedbackEmailFallback = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                MujoIdentityHeader()
                    .accessibilityAddTraits(.isHeader)

                storySection("Why I built Mujø", paragraphs: [
                    "Mujø is my first iOS app. I wanted to learn Swift by building something I'd use myself. I was spending more time on my phone than I wanted, and the screen time apps I tried felt overwhelming. I wanted something I could check at a glance.",
                    "Once, I hit an app limit while writing a message. When I got back into the app, my draft was gone. With Mujø, I get reminders before I reach my limit. My apps stay open, so I can finish what I'm doing and decide when to put my phone down.",
                ])

                storySection("Why it counts down", paragraphs: [
                    "Other screen time apps I tried showed how much time I'd already spent. I wanted to see how much I had left. If I see 30 minutes left, I can decide better how to use them. When I see zero, I know I've reached the limit I set and it talks to me there is no way how to extend it.",
                    "Mujø counts down while you use apps and websites. Time on the Home Screen or Lock Screen doesn't count. Incognito pages don't count either.",
                ])

                storySection("Why the name Mujø", paragraphs: [
                    "Mujō is the Japanese word for impermanence. The cherry blossoms in the app are a reminder of what that means. They bloom for a short time, then fall. For me, the countdown is another reminder to think about how I spend the time I have.",
                    "I chose ø for the name as a nod to the symbol for an empty set in mathematics. When the countdown reaches zero, there's no screen time left in my daily limit.",
                ])

                storySection("About me", paragraphs: [
                    authorIntroduction,
                    "I enjoy designing interfaces and figuring out what makes them easy to use. I'm happy to spend hours on the small details that help an app feel simple.",
                ])

                storySection("Aikari Studio", paragraphs: [
                    "That care is part of what Aikari Studio stands for. The name brings together ai, meaning love, and ikari, meaning anger in japanese. I recognize both in my work. I love making things, and when I see how something could work better, I want to fix it.",
                    "I think of Aikari as a small fire lit for the neighbors. I want to make things that help people and encourage them to take pride in their own work. Working with care teaches me patience, and that stays with me after the work is done.",
                    "I'm figuring out how to use AI in my work. I want it to help me learn new skills while I make the decisions and take responsibility for what I put out.",
                    "If Mujø helps you get a little of your day back, it's done what I hoped it would. More apps and websites are on the way.",
                ])

                contactSection

                Image(decorative: "AikariStudioLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 112)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
            .background { brandGradient }
        }
        .background { brandGradient.ignoresSafeArea() }
        .tint(.accentColor)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .background { PinkNavigationBackIndicator() }
        .alert(
            "Couldn’t open email",
            isPresented: $isShowingFeedbackEmailFallback,
            presenting: FeedbackEmail.recipient
        ) { address in
            Button("Copy Email Address") {
                UIPasteboard.general.string = address
            }
            Button("Cancel", role: .cancel) { }
        } message: { address in
            Text("You can send feedback to \(address).")
        }
    }

    private var brandGradient: LinearGradient {
        let mujoPink = MujoTheme.surfaceBackground(for: colorScheme)
        let deeperPink = MujoTheme.raisedSurfaceBackground(for: colorScheme)
        let aikariOrange = Color(red: 240.0 / 255, green: 80.0 / 255, blue: 41.0 / 255)
        let orangeBackground = mujoPink.mix(with: aikariOrange, by: colorScheme == .dark ? 0.34 : 0.24)

        return LinearGradient(
            stops: [
                .init(color: mujoPink, location: 0),
                .init(color: deeperPink, location: 0.18),
                .init(color: orangeBackground, location: 0.92),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var authorIntroduction: LocalizedStringKey {
        if let name = Self.authorName {
            return "I'm \(name). I studied technology at university and worked as a front-end developer for a few years."
        }

        return "I studied technology at university and worked as a front-end developer for a few years."
    }

    private func storySection(
        _ title: LocalizedStringKey,
        paragraphs: [LocalizedStringKey]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)

            ForEach(paragraphs.indices, id: \.self) { index in
                Text(paragraphs[index])
                    .font(.body)
                    .lineSpacing(3)
            }
        }
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            storySection("Get in touch", paragraphs: [
                "I'd love to hear how Mujø is working for you. If there's another app you wish existed, tell me what it would help you do.",
            ])

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 44), spacing: 8)]) {
                Button(action: sendFeedback) {
                    contactIcon(Image(systemName: "envelope"))
                }
                .accessibilityLabel("Send Feedback")

                ForEach(Self.socialLinks.indices, id: \.self) { index in
                    let socialLink = Self.socialLinks[index]
                    if let url = URL(string: socialLink.urlString) {
                        Button {
                            openURL(url)
                        } label: {
                            contactIcon(Image(decorative: socialLink.icon))
                        }
                        .accessibilityLabel(Text(socialLink.title))
                        .accessibilityRemoveTraits(.isButton)
                        .accessibilityAddTraits(.isLink)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 304)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(Color.primary)
        .tint(.primary)
    }

    private func contactIcon(_ image: Image) -> some View {
        image
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
            .frame(width: 44, height: 44)
            .background(.primary.opacity(0.08), in: Circle())
            .contentShape(.interaction, Circle())
    }

    private func sendFeedback() {
        guard let recipient = FeedbackEmail.recipient else {
            if let supportURL = URL(string: FeedbackEmail.supportPage) {
                openURL(supportURL)
            }
            return
        }

        guard let url = FeedbackEmail.draftURL(
            recipient: recipient,
            appVersion: AppInfoMetadata().version,
            iOSVersion: UIDevice.current.systemVersion
        ) else {
            isShowingFeedbackEmailFallback = true
            return
        }

        openURL(url) { accepted in
            if !accepted {
                isShowingFeedbackEmailFallback = true
            }
        }
    }
}

#if DEBUG
#Preview("About · Light") {
    NavigationStack { AboutScreen() }
        .preferredColorScheme(.light)
}

#Preview("About · Dark") {
    NavigationStack { AboutScreen() }
        .preferredColorScheme(.dark)
}
#endif
