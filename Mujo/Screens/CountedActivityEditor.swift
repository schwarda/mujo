import Accessibility
import FamilyControls
import SwiftUI

struct CountedActivityEditor: View {
    static func backgroundColor(for colorScheme: ColorScheme) -> Color {
        // Sampled from the system picker's light background in Display P3.
        colorScheme == .light
            ? Color(.displayP3, red: 242.0 / 255, green: 242.0 / 255, blue: 246.0 / 255)
            : Color(uiColor: .systemGroupedBackground)
    }

    @Environment(\.colorScheme) private var colorScheme

    let isOnboarding: Bool
    let showsPreviewData: Bool
    let onSave: (FamilyActivitySelection) async throws -> Void
    let onCompletion: () -> Void

    private let originalSelection: FamilyActivitySelection?
    @State private var draft: FamilyActivitySelection
    @State private var isSaving = false
    @State private var isConfirmingAllApps = false
    @State private var errorMessage: String?

    init(
        selection: FamilyActivitySelection?,
        isOnboarding: Bool,
        showsPreviewData: Bool,
        onSave: @escaping (FamilyActivitySelection) async throws -> Void,
        onCompletion: @escaping () -> Void
    ) {
        originalSelection = selection
        _draft = State(initialValue: selection ?? FamilyActivitySelection())
        self.isOnboarding = isOnboarding
        self.showsPreviewData = showsPreviewData
        self.onSave = onSave
        self.onCompletion = onCompletion
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Choose what counts")
                .font(MujoTheme.boldFont(size: 40, relativeTo: .largeTitle))
                .foregroundStyle(.tint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 34)
                .padding(.top, isOnboarding ? OnboardingLayoutMetrics.topHeadingPadding : 32)
                .padding(.bottom, 8)

            picker
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    pickerEdgeBlur
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .disabled(isSaving)

            footer
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
        }
        .background(Self.backgroundColor(for: colorScheme).ignoresSafeArea())
        .interactiveDismissDisabled(isSaving)
        .alert("Count All Apps?", isPresented: $isConfirmingAllApps) {
            Button("Cancel", role: .cancel) {}
            Button("Count All Apps", action: save)
        } message: {
            Text("Screen Time access changed. You can select apps and websites again or count all activity.")
        }
    }

    @ViewBuilder
    private var picker: some View {
        if showsPreviewData {
            ContentUnavailableView(
                "Apps and Websites",
                systemImage: "square.grid.2x2",
                description: Text("The Screen Time picker is available on your iPhone.")
            )
        } else {
            FamilyActivityPicker(selection: $draft)
        }
    }

    private var pickerEdgeBlur: some View {
        VStack(spacing: 0) {
            pickerEdge(from: .top, to: .bottom)

            Spacer(minLength: 0)

            pickerEdge(from: .bottom, to: .top)
        }
    }

    private func pickerEdge(from outerEdge: UnitPoint, to innerEdge: UnitPoint) -> some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask {
                LinearGradient(colors: [.black, .clear], startPoint: outerEdge, endPoint: innerEdge)
            }
            // Soften the material's tint where it becomes visible in dark mode.
            .opacity(colorScheme == .dark ? 0.45 : 1)
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: Self.backgroundColor(for: colorScheme), location: 0),
                        .init(color: .clear, location: 0.75)
                    ],
                    startPoint: outerEdge,
                    endPoint: innerEdge
                )
            }
            .frame(height: 20)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
            } else if !isOnboarding, didChangeSelection {
                Text("Saving starts today’s count over.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            OnboardingPrimaryButton(isDisabled: isSaving, action: confirmSelection) {
                if isSaving {
                    ProgressView()
                        .accessibilityLabel("Saving")
                } else {
                    Text(isOnboarding ? "Continue" : "Save")
                }
            }
        }
        .multilineTextAlignment(.center)
    }

    private var didChangeSelection: Bool {
        guard let originalSelection else { return true }
        return !draft.countsSameActivity(as: originalSelection)
    }

    private func confirmSelection() {
        if originalSelection == nil, draft.countsAllActivity {
            isConfirmingAllApps = true
        } else {
            save()
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        let selection = draft
        Task {
            do {
                try await onSave(selection)
                isSaving = false
                onCompletion()
            } catch {
                let message = error.localizedDescription
                errorMessage = message
                isSaving = false
                AccessibilityNotification.Announcement(message).post()
            }
        }
    }
}

struct CountedActivitySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var screenTime: ScreenTimeManager

    var body: some View {
        CountedActivityEditor(
            selection: screenTime.countedActivitySelection,
            isOnboarding: false,
            showsPreviewData: screenTime.usesSimulatedData,
            onSave: screenTime.saveCountedActivity,
            onCompletion: { dismiss() }
        )
        .presentationBackground(CountedActivityEditor.backgroundColor(for: colorScheme))
    }
}

#if DEBUG
#Preview("Counted Apps · Sheet") {
    CountedActivityEditor(
        selection: FamilyActivitySelection(),
        isOnboarding: false,
        showsPreviewData: true,
        onSave: { _ in },
        onCompletion: {}
    )
}
#endif
