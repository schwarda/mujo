import SwiftUI

struct OnboardingInsightsAndLimitReportSection<ReportContent: View>: View {
    let isChoosingLimit: Bool
    let showsHistoryReport: Bool
    let motionStyle: OnboardingMotionStyle
    private let reportContent: () -> ReportContent

    init(
        isChoosingLimit: Bool,
        showsHistoryReport: Bool,
        motionStyle: OnboardingMotionStyle,
        @ViewBuilder reportContent: @escaping () -> ReportContent
    ) {
        self.isChoosingLimit = isChoosingLimit
        self.showsHistoryReport = showsHistoryReport
        self.motionStyle = motionStyle
        self.reportContent = reportContent
    }

    var body: some View {
        Group {
            if isChoosingLimit {
                Group {
                    Text("Take the first step")
                        .font(MujoTheme.boldFont(size: 40, relativeTo: .largeTitle))
                        .foregroundStyle(.tint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(
                        "Set the amount of screen time\nyou want to give yourself each day."
                    )
                    .font(MujoTheme.italicFont(
                        size: OnboardingTypography.descriptive,
                        relativeTo: .body
                    ))
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)

                    Spacer(minLength: 12)
                }
                .transition(motionStyle.transition)
            } else {
                Group {
                    Text("Before you\nchoose, know\nwhere you are")
                        .font(MujoTheme.boldFont(
                            size: 40,
                            relativeTo: .largeTitle
                        ))
                        .foregroundStyle(.tint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(2)
                        .padding(
                            .top,
                            OnboardingLayoutMetrics.topHeadingPadding
                        )

                    Spacer(minLength: 32)
                }
                .transition(motionStyle.transition)
            }

            if showsHistoryReport {
                reportContent()
                    .frame(height: isChoosingLimit ? 72 : nil)
                    .frame(maxHeight: isChoosingLimit ? nil : 460)
                    .layoutPriority(1)
                    .padding(.horizontal, isChoosingLimit ? 32 : 0)
                    .allowsHitTesting(!isChoosingLimit)
            }
        }
    }
}
struct OnboardingLimitSelectionSection: View {
    @State private var selectedMinutes: Int
    @State private var isSaving = false

    let onSave: (Int) async -> Bool
    let hidesSelectedTime: Bool
    let onSelectedTimeFrameChange: (CGRect) -> Void

    init(
        initialMinutes: Int,
        hidesSelectedTime: Bool,
        onSelectedTimeFrameChange: @escaping (CGRect) -> Void,
        onSave: @escaping (Int) async -> Bool
    ) {
        _selectedMinutes = State(initialValue: initialMinutes)
        self.hidesSelectedTime = hidesSelectedTime
        self.onSelectedTimeFrameChange = onSelectedTimeFrameChange
        self.onSave = onSave
    }

    var body: some View {
        Group {
            Text(selectedTime)
                .font(MujoTheme.boldFont(
                    size: 88,
                    relativeTo: .largeTitle
                ))
                .monospacedDigit()
                .foregroundStyle(.tint)
                .contentTransition(.numericText())
                .opacity(hidesSelectedTime ? 0 : 1)
                .onGeometryChange(
                    for: CGRect.self,
                    of: { proxy in
                        proxy.frame(in: .named(
                            OnboardingCoordinateSpace.limitSetup
                        ))
                    },
                    action: onSelectedTimeFrameChange
                )

            Text("Daily limit")
                .font(MujoTheme.italicFont(
                    size: OnboardingTypography.descriptive,
                    relativeTo: .subheadline
                ))
                .foregroundStyle(.tint)
                .padding(.top, -6)

            TimeDial(
                minutes: $selectedMinutes,
                windStrength: .constant(0),
                allowsEmptySelection: true,
                showsValue: false,
                onValueChange: { _ in },
                onCommit: { _ in }
            )
            .padding(.top, 24)

            Spacer(minLength: 22)

            OnboardingPrimaryButton(
                isDisabled: selectedMinutes == 0 || isSaving,
                action: saveLimit
            ) {
                if isSaving {
                    ProgressView()
                } else {
                    Text("Set limit")
                }
            }
            .padding(.horizontal, 34)

            Text("You can always change your limit later.")
                .font(MujoTheme.italicFont(
                    size: OnboardingTypography.supporting,
                    relativeTo: .subheadline
                ))
                .foregroundStyle(.tint)
                .padding(.top, 7)
                .opacity(selectedMinutes == 0 ? 0 : 1)
                .accessibilityHidden(selectedMinutes == 0)
        }
    }

    private var selectedTime: String {
        OnboardingDurationFormatter.string(
            minutes: selectedMinutes,
            emptyPlaceholder: "–"
        )
    }

    private func saveLimit() {
        guard selectedMinutes > 0, !isSaving else { return }

        isSaving = true
        let minutes = selectedMinutes
        Task {
            if !(await onSave(minutes)) {
                isSaving = false
            }
        }
    }
}
