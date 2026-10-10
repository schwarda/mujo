import DeviceActivity
import SwiftUI
import UIKit

// Keep ownership of the sheet on a UIKit container, outside the SwiftUI
// hierarchy that embeds DeviceActivityReport's remote view controller.
struct DailyLimitSheetPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let screenTime: ScreenTimeManager
    @Binding var windStrength: Double

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AnchorController {
        let anchor = AnchorController()
        anchor.onAppear = { [weak coordinator = context.coordinator, weak anchor] in
            guard let anchor else { return }
            coordinator?.updatePresentation(from: anchor)
        }
        return anchor
    }

    func updateUIViewController(_ anchor: AnchorController, context: Context) {
        context.coordinator.configuration = self
        context.coordinator.updatePresentation(from: anchor)
    }

    static func dismantleUIViewController(_ anchor: AnchorController, coordinator: Coordinator) {
        coordinator.discardCachedSheet()
    }

    final class AnchorController: UIViewController {
        var onAppear: (() -> Void)?

        override func loadView() {
            view = UIView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            onAppear?()
        }
    }

    final class Coordinator: NSObject, UISheetPresentationControllerDelegate {
        var configuration: DailyLimitSheetPresenter?
        var sheet: UIViewController?
        private var hosting: UIHostingController<DailyLimitEditorScreen>?
        private weak var presentationAnchor: UIViewController?
        private var isDismissing = false
        private var cachedReportDay: Date?

        func updatePresentation(from anchor: UIViewController) {
            guard let configuration else { return }
            presentationAnchor = anchor
            discardCachedSheetIfExpired()

            if !configuration.isPresented {
                guard let sheet,
                      sheet.presentingViewController != nil,
                      !isDismissing
                else { return }
                isDismissing = true
                sheet.dismiss(animated: true) { [weak self] in self?.didDismiss() }
                return
            }

            guard !isDismissing,
                  anchor.viewIfLoaded?.window != nil,
                  anchor.presentedViewController == nil
            else { return }

            let container = UIViewController()
            container.modalPresentationStyle = .pageSheet
            let hosting = cachedHosting(for: configuration)
            container.addChild(hosting)
            container.view.addSubview(hosting.view)
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hosting.view.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: container.view.trailingAnchor),
                hosting.view.topAnchor.constraint(equalTo: container.view.topAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: container.view.bottomAnchor)
            ])
            hosting.didMove(toParent: container)
            if let presentation = container.sheetPresentationController {
                presentation.detents = [.large()]
                presentation.prefersGrabberVisible = true
                presentation.prefersScrollingExpandsWhenScrolledToEdge = false
                presentation.delegate = self
            }
            sheet = container
            anchor.present(container, animated: true)
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            didDismiss()
        }

        private func didDismiss() {
            guard let sheet else { return }
            detachHosting(from: sheet)
            self.sheet = nil
            isDismissing = false
            configuration?.isPresented = false
        }

        private func cachedHosting(
            for configuration: DailyLimitSheetPresenter
        ) -> UIHostingController<DailyLimitEditorScreen> {
            if let hosting {
                return hosting
            }

            let content = DailyLimitEditorScreen(
                screenTime: configuration.screenTime,
                windStrength: configuration.$windStrength,
                onSaved: { [weak self] in
                    guard let self else { return }
                    self.configuration?.isPresented = false
                    if let presentationAnchor {
                        updatePresentation(from: presentationAnchor)
                    }
                }
            )
            let hosting = UIHostingController(rootView: content)
            hosting.view.backgroundColor = .clear
            self.hosting = hosting
            cachedReportDay = Calendar.autoupdatingCurrent.startOfDay(for: .now)
            return hosting
        }

        private func detachHosting(from container: UIViewController) {
            guard let hosting, hosting.parent === container else { return }
            hosting.willMove(toParent: nil)
            hosting.view.removeFromSuperview()
            hosting.removeFromParent()
        }

        private func discardCachedSheetIfExpired() {
            let today = Calendar.autoupdatingCurrent.startOfDay(for: .now)
            guard let cachedReportDay,
                  cachedReportDay != today,
                  sheet == nil,
                  !isDismissing
            else { return }

            hosting = nil
            self.cachedReportDay = nil
        }

        func discardCachedSheet() {
            sheet?.dismiss(animated: false)
            if let sheet {
                detachHosting(from: sheet)
            }
            sheet = nil
            hosting = nil
            cachedReportDay = nil
            isDismissing = false
        }
    }
}
private struct DailyLimitEditorScreen: View {
    let onSaved: () -> Void
    @ObservedObject var screenTime: ScreenTimeManager
    @Binding var windStrength: Double

    @State private var selectedMinutes: Int
    @State private var isSaving = false

    init(
        screenTime: ScreenTimeManager,
        windStrength: Binding<Double>,
        onSaved: @escaping () -> Void
    ) {
        self.onSaved = onSaved
        self.screenTime = screenTime
        _windStrength = windStrength
        _selectedMinutes = State(initialValue: screenTime.dailyLimitMinutes)
    }

    var body: some View {
        ZStack {
            OnboardingBackground()

            VStack(spacing: 0) {

                Text("Choose your\ndaily limit")
                    .font(MujoTheme.boldFont(size: 40, relativeTo: .largeTitle))
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)
                    .accessibilityIdentifier("daily-limit-heading")

                // The report owns its private data and stays mounted while editing.
                // An App Group acknowledgement cannot determine report readiness.
                ZStack {
                    ScreenTimeReportLoadingView(
                        message: "Loading your average time…"
                    )

                    ScreenTimeReportView(
                        context: .mujoLimitEditorDescription,
                        filter: sevenDayReportFilter
                    )
                    .equatable()
                    .allowsHitTesting(false)
                }
                .frame(height: 72)
                .padding(.horizontal, 24)
                .padding(.top, 32)

                Spacer(minLength: 18)

                Text(formattedLimit)
                    .font(.system(size: 88, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.tint)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)

                Text("new daily limit")
                    .font(MujoTheme.italicFont(size: 18, relativeTo: .body))
                    .foregroundStyle(
                        .tint.opacity(MujoTheme.secondaryTextOpacity)
                    )
                    .padding(.top, -8)

                TimeDial(
                    minutes: $selectedMinutes,
                    windStrength: $windStrength,
                    showsValue: false,
                    onValueChange: { _ in },
                    onCommit: { _ in }
                )
                .padding(.top, 40)

                Spacer(minLength: 18)

                OnboardingPrimaryButton(isDisabled: isSaving) {
                    saveLimit()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Set limit")
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            selectedMinutes = screenTime.dailyLimitMinutes
            isSaving = false
        }
    }

    private var sevenDayReportFilter: DeviceActivityFilter {
        let calendar = Calendar.autoupdatingCurrent
        let end = calendar.startOfDay(for: .now)
        let start = calendar.date(
            byAdding: .day,
            value: -OnboardingProjectionRules.recentDayCount,
            to: end
        ) ?? end

        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: end)),
            users: .all,
            devices: .all
        )
    }

    private var formattedLimit: String {
        let hours = selectedMinutes / 60
        let minutes = selectedMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }

    private func saveLimit() {
        guard !isSaving else { return }
        isSaving = true

        Task {
            await screenTime.setDailyLimit(minutes: selectedMinutes)
            isSaving = false
            guard screenTime.errorMessage == nil else { return }
            onSaved()
        }
    }
}
