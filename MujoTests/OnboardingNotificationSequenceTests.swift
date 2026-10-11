import CoreGraphics
import Testing
@testable import Mujo

@Suite("Onboarding notification sequence")
struct OnboardingNotificationSequenceTests {
    @Test("The preview reveals each notification once and keeps the final stack")
    func revealsNotificationsOnce() {
        var phase = OnboardingNotificationStackPhase.hidden

        phase.advance()
        #expect(phase == .thirtyMinutes)
        #expect(phase.visibleNotificationCount == 1)

        phase.advance()
        #expect(phase == .fiveMinutes)
        #expect(phase.visibleNotificationCount == 2)

        phase.advance()
        #expect(phase == .expired)
        #expect(phase.visibleNotificationCount == 3)

        phase.advance()
        #expect(phase == .expired)
        #expect(phase.visibleNotificationCount == 3)
    }

    @Test("Reduce Motion starts with the completed notification stack")
    func reduceMotionStartsCompleted() {
        #expect(
            OnboardingNotificationStackPhase.initial(
                reduceMotionEnabled: true
            ) == .expired
        )
        #expect(
            OnboardingNotificationStackPhase.initial(
                reduceMotionEnabled: false
            ) == .hidden
        )
    }

    @Test("Every older notification exposes an equally tall bottom edge")
    func exposesEqualBottomEdges() {
        let layout = OnboardingNotificationStackLayout()
        let middleEdge = layout.exposedBottomEdge(atDepth: 1)
        let backEdge = layout.exposedBottomEdge(atDepth: 2)

        #expect(abs(middleEdge - backEdge) < 0.001)
        #expect(middleEdge >= 10)
    }
}
