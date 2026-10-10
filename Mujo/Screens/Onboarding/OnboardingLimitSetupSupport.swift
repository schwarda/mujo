import SwiftUI

enum OnboardingInteractionMetrics {
    static let stepAnimationDuration = 0.3
}
enum OnboardingPreviewData {
    static let dailyAverageMinutes = 210
    static let initialLimitMinutes = 120
}

enum OnboardingAssetName {
    static let badgeLight = "Badge_light"
    static let badgeDark = "Badge_dark"
    static let homeScreenWidgetLight = "HomeScreenWidget_light"
    static let homeScreenWidgetDark = "HomeScreenWidget_dark"
    static let launchLogo = "LaunchLogo"
}

enum OnboardingLayoutMetrics {
    static let topHeadingPadding: CGFloat = 34
    static let savingsReportMinimumHeight: CGFloat = 420
    static let lockScreenAspectRatio: CGFloat = 1.2
    static let homeScreenWidgetMaximumWidth: CGFloat = 360
    static let homeScreenWidgetCornerRadius: CGFloat = 42
    static let badgeMaximumSize: CGFloat = 270
    static let badgeCornerRadius: CGFloat = 32
}

struct AdaptiveOnboardingStep<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

enum OnboardingInsightPage: Int, CaseIterable {
    case day
    case week
    case year
}
