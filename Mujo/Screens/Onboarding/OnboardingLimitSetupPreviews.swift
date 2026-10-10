import SwiftUI

#if DEBUG
private struct OnboardingScreenPreview: View {
    let step: OnboardingLimitSetupView.Step
    var insightPage: OnboardingInsightPage = .day

    var body: some View {
        ZStack {
            OnboardingBackground()
            OnboardingLimitSetupView(
                previewStep: step,
                insightPage: insightPage
            )
        }
    }
}

#Preview("01 · Average day") {
    OnboardingScreenPreview(step: .insights, insightPage: .day)
}

#Preview("02 · Week") {
    OnboardingScreenPreview(step: .insights, insightPage: .week)
}

#Preview("03 · Year") {
    OnboardingScreenPreview(step: .insights, insightPage: .year)
}

#Preview("04 · Choose limit") {
    OnboardingScreenPreview(step: .chooseLimit)
}

#Preview("05 · Annual savings") {
    OnboardingScreenPreview(step: .savings)
}

#Preview("06 · Limit reached") {
    OnboardingScreenPreview(step: .limitReached)
}

#Preview("07 · Notifications") {
    OnboardingScreenPreview(step: .notifications)
}

#Preview("08 · Lock Screen widget") {
    OnboardingScreenPreview(step: .lockScreenWidget)
}

#Preview("09 · Home Screen widget") {
    OnboardingScreenPreview(step: .homeScreenWidget)
}
#endif
