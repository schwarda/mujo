//
//  HomeScreen.swift
//  Mujo
//
//  Created by Lopk Art on 06/09/2026.
//

import DeviceActivity
import SwiftUI

nonisolated private struct HomeNoticeGeometry: Equatable, Sendable {
    let visualFrame: CGRect
    let layoutHeight: CGFloat
}

struct HomeScreen: View {
    nonisolated private static let noticeSpacing: CGFloat = 8
    nonisolated private static let noticeStackStep: CGFloat = 14
    nonisolated private static let noticeTopFadeHeight: CGFloat = 36

    private struct HomeNotice: Identifiable {
        enum ID: Hashable {
            case timeZoneChanged
            case firstDay
            case debug(Int)
        }

        let id: ID
        let title: String
        let message: String
    }

    private static let timeZoneNotice = HomeNotice(
        id: .timeZoneChanged,
        title: "Time zone changed",
        message: "Adjusting to your new time zone. "
            + "Your daily limit stays the same."
    )

    private static let firstDayNotice = HomeNotice(
        id: .firstDay,
        title: "Your first day",
        message: "Today, usage counts from when you started using Mujø. "
            + "From tomorrow, it will count from midnight."
    )

#if DEBUG
    private static let debugNotices = [
        HomeNotice(
            id: .debug(1),
            title: "Test card 1",
            message: "A short message for checking the compact card height."
        ),
        HomeNotice(
            id: .debug(2),
            title: "Test card 2",
            message: "This message is a little longer so it should wrap "
                + "across two lines on smaller iPhones."
        ),
        HomeNotice(
            id: .debug(3),
            title: "Test card 3",
            message: "Scroll through the stack to confirm that each card "
                + "becomes readable when it reaches the active position."
        ),
        HomeNotice(
            id: .debug(4),
            title: "Test card 4",
            message: "The frosted effect should grow smoothly while this "
                + "card overlaps the one below it."
        ),
        HomeNotice(
            id: .debug(5),
            title: "Test card 5",
            message: "Last test card. Scrolling should stop when this card "
                + "reaches the active position."
        ),
    ]
#endif

    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var screenTime: ScreenTimeManager

    @Binding var windStrength: Double
    @Binding var petalSimulationTime: Double
    @Binding var petalFlow: SakuraPetalFlowState
    let petalsStartFilled: Bool
    let showsPetals: Bool

    @State private var previewMinutes: Int?
    @State private var isShowingLimitEditor = false
    @State private var noticeGeometries: [HomeNotice.ID: HomeNoticeGeometry] = [:]

#if DEBUG
    @State private var isShowingDiagnostics = false
    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = true
#endif

    var body: some View {
        ZStack {
            if showsPetals {
                SakuraPetalField(
                    windStrength: windStrength,
                    startsFilled: petalsStartFilled,
                    simulationTime: $petalSimulationTime,
                    emitsPetals: shouldEmitPetals,
                    flowState: $petalFlow
                )
            }

            VStack(spacing: 0) {
                remainingTimeView
                    .frame(minHeight: 200)
                    .padding(.top, 64)

                homeNoticesView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                Button("Change daily limit ›") {
                    isShowingLimitEditor = true
                }
                .font(MujoTheme.mediumFont(
                    size: OnboardingTypography.supporting,
                    relativeTo: .body
                ))
                .foregroundStyle(.tint)
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .padding(.bottom, 80)
                
            }

#if DEBUG
            VStack {
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasCompletedOnboarding = false
                        }
                    } label: {
                        Label(
                            "Replay onboarding",
                            systemImage: "arrow.counterclockwise"
                        )
                    }
                    .buttonStyle(.glass)
                    .foregroundStyle(.tint)

                    Spacer()

                    Button {
                        isShowingDiagnostics = true
                    } label: {
                        Label("Diagnostics", systemImage: "stethoscope")
                    }
                    .buttonStyle(.glass)
                    .foregroundStyle(.tint)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
#endif
        }
        .task {
            await refreshUsageWhileVisible()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            screenTime.refreshUsageSnapshot()
            screenTime.requestWidgetReload()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name.NSSystemTimeZoneDidChange
            )
        ) { _ in
            screenTime.refreshUsageSnapshot()
        }
        .background {
            DailyLimitSheetPresenter(
                isPresented: $isShowingLimitEditor,
                screenTime: screenTime,
                windStrength: $windStrength
            )
        }
#if DEBUG
        .sheet(isPresented: $isShowingDiagnostics) {
            DiagnosticsView(screenTime: screenTime)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
#endif
    }

    private var selectedMinutes: Int {
        previewMinutes ?? screenTime.dailyLimitMinutes
    }

    private var shouldEmitPetals: Bool {
        let estimate = screenTime.usageEstimate(
            forLimitMinutes: selectedMinutes
        )
        return estimate.isAvailable && estimate.remainingTime > 0
    }

    @ViewBuilder
    private var remainingTimeView: some View {
        let estimate = screenTime.usageEstimate(
            forLimitMinutes: selectedMinutes
        )

        VStack(spacing: 6) {
            VStack {
                Text("R e m a i n i n g")
                    .font(MujoTheme.mediumFont(
                        size: 12,
                        relativeTo: .caption2
                    ))
                    .textCase(.uppercase)
                    .foregroundStyle(
                        MujoTheme.glassAccent.opacity(
                            MujoTheme.secondaryTextOpacity
                        )
                    )

                if estimate.isAvailable {
                    GlassText(value: estimate.remainingTime.formatted())
                        .fixedSize(horizontal: true, vertical: true)
                } else if estimate.unavailableReason == .timeZoneChanged {
                    Text("-")
                        .font(MujoTheme.boldFont(
                            size: 76,
                            relativeTo: .largeTitle
                        ))
                        .foregroundStyle(MujoTheme.glassAccent)
                } else {
                    Text("Waiting for data")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(
                            MujoTheme.glassAccent.opacity(
                                MujoTheme.secondaryTextOpacity
                            )
                        )
                }
            }

            if estimate.isAvailable {
                Text(usageSummary)
                .font(MujoTheme.italicFont(size: 22, relativeTo: .body))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .foregroundStyle(
                    MujoTheme.glassAccent.opacity(
                        MujoTheme.secondaryTextOpacity
                    )
                )
            }
        }
        .padding()
    }

    @ViewBuilder
    private var homeNoticesView: some View {
        let notices = homeNotices

        if notices.isEmpty {
            Color.clear
        } else {
            GeometryReader { container in
                let stackAnchorY = container.size.height * 0.64

                ScrollView(.vertical) {
                    VStack(spacing: Self.noticeSpacing) {
                        ForEach(
                            Array(notices.enumerated()),
                            id: \.element.id
                        ) { index, notice in
                            homeNoticeCard(
                                notice,
                                frozenAmount: noticeFrozenAmount(
                                    at: index,
                                    in: notices
                                )
                            )
                            .visualEffect { content, proxy in
                                content
                                    .scaleEffect(
                                        noticeStackScale(
                                            proxy,
                                            anchorY: stackAnchorY
                                        ),
                                        anchor: .top
                                    )
                                    .offset(
                                        y: noticeStackOffset(
                                            proxy,
                                            anchorY: stackAnchorY
                                        )
                                    )
                            }
                            .onGeometryChange(
                                for: HomeNoticeGeometry.self,
                                of: { proxy in
                                    noticeGeometry(
                                        proxy,
                                        anchorY: stackAnchorY
                                    )
                                },
                                action: { geometry in
                                    noticeGeometries[notice.id] = geometry
                                }
                            )
                            .zIndex(Double(notices.count - index))
                        }
                    }
                    .padding(.top, stackAnchorY)
                    .padding(.bottom, noticeBottomPadding(
                        for: notices,
                        containerHeight: container.size.height,
                        anchorY: stackAnchorY
                    ))
                }
                .scrollIndicators(.hidden)
                .scrollDisabled(notices.count < 2)
                .id(notices.map(\.id))
                .mask(alignment: .top) {
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: Self.noticeTopFadeHeight)

                        Color.black
                    }
                }
            }
        }
    }

    nonisolated private func noticeStackProgress(
        _ proxy: GeometryProxy,
        anchorY: CGFloat
    ) -> CGFloat {
        let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
        let distanceFromAnchor = max(minY - anchorY, 0)
        let itemStride = max(proxy.size.height + Self.noticeSpacing, 1)
        return distanceFromAnchor / itemStride
    }

    nonisolated private func noticeStackOffset(
        _ proxy: GeometryProxy,
        anchorY: CGFloat
    ) -> CGFloat {
        let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
        let distanceFromAnchor = max(minY - anchorY, 0)
        let visibleDepth = min(
            noticeStackProgress(proxy, anchorY: anchorY),
            2
        )
        return -distanceFromAnchor + visibleDepth * Self.noticeStackStep
    }

    nonisolated private func noticeStackScale(
        _ proxy: GeometryProxy,
        anchorY: CGFloat
    ) -> CGFloat {
        let visibleDepth = min(
            noticeStackProgress(proxy, anchorY: anchorY),
            2
        )
        return 1 - visibleDepth * 0.025
    }

    nonisolated private func noticeGeometry(
        _ proxy: GeometryProxy,
        anchorY: CGFloat
    ) -> HomeNoticeGeometry {
        let frame = proxy.frame(in: .scrollView(axis: .vertical))
        let scale = noticeStackScale(proxy, anchorY: anchorY)
        let scaledSize = CGSize(
            width: frame.width * scale,
            height: frame.height * scale
        )

        return HomeNoticeGeometry(
            visualFrame: CGRect(
                x: frame.minX + (frame.width - scaledSize.width) / 2,
                y: frame.minY + noticeStackOffset(proxy, anchorY: anchorY),
                width: scaledSize.width,
                height: scaledSize.height
            ),
            layoutHeight: proxy.size.height
        )
    }

    private func noticeBottomPadding(
        for notices: [HomeNotice],
        containerHeight: CGFloat,
        anchorY: CGFloat
    ) -> CGFloat {
        guard let lastNotice = notices.last,
              let lastHeight = noticeGeometries[lastNotice.id]?.layoutHeight
        else { return 0 }

        return max(containerHeight - anchorY - lastHeight, 0)
    }

    private func noticeFrozenAmount(
        at index: Int,
        in notices: [HomeNotice]
    ) -> Double {
        guard let currentFrame = noticeGeometries[
            notices[index].id
        ]?.visualFrame
        else { return 0 }

        let adjacentIndices = [index - 1, index + 1]
            .filter(notices.indices.contains)

        let largestOverlap = adjacentIndices.reduce(CGFloat.zero) {
            currentLargestOverlap, adjacentIndex in
            guard let adjacentFrame = noticeGeometries[
                notices[adjacentIndex].id
            ]?.visualFrame
            else { return currentLargestOverlap }

            let overlap = currentFrame.intersection(adjacentFrame).height
            let maximumOverlap = max(
                min(currentFrame.height, adjacentFrame.height)
                    - Self.noticeStackStep,
                1
            )
            return max(currentLargestOverlap, overlap / maximumOverlap)
        }

        return Double(min(max(largestOverlap * 1.15, 0), 1))
    }

    private func homeNoticeCard(
        _ notice: HomeNotice,
        frozenAmount: Double
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 32, weight: .regular))
                .frame(width: 40, height: 40)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(notice.title)
                    .font(.system(
                        size: OnboardingTypography.systemUI,
                        weight: .semibold
                    ))

                Text(notice.message)
                    .font(.system(
                        size: OnboardingTypography.systemUI,
                        weight: .regular
                    ))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(MujoTheme.glassAccent)
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
        .background {
            Color.clear
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
                .opacity(frozenAmount)
        }
        .glassEffect(.clear, in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }

    private func refreshUsageWhileVisible() async {
        while !Task.isCancelled {
            if scenePhase == .active {
                screenTime.refreshUsageSnapshot()
            }

            try? await Task.sleep(for: .seconds(1))
        }
    }

    private var displayedUsedTime: TimeInterval {
        let usedTime = screenTime.usageSnapshot.estimatedUsedTime
        let limit = TimeInterval(selectedMinutes * 60)
        let coarseStep = TimeInterval(
            AppConfiguration.DailyLimit.stepMinutes * 60
        )

        guard usedTime < limit else {
            return floor(usedTime / coarseStep) * coarseStep
        }

        let remainingTime = limit - usedTime
        let resolutionMinutes = AppConfiguration.DailyLimit
            .displayResolutionMinutes(
                remainingTime: remainingTime,
                dailyLimit: limit
            )
        let resolution = TimeInterval(resolutionMinutes * 60)
        return floor(usedTime / resolution) * resolution
    }

    private var usageSummary: String {
        let formattedLimit = OnboardingDurationFormatter.string(
            minutes: selectedMinutes
        )
        let formattedUsedTime = OnboardingDurationFormatter.string(
            minutes: Int(displayedUsedTime) / 60
        )
        return "\(formattedUsedTime) used · \(formattedLimit) limit"
    }

    private var homeNotices: [HomeNotice] {
#if DEBUG
        // Temporary physical-device preview for the multi-card stack.
        return [Self.timeZoneNotice, Self.firstDayNotice] + Self.debugNotices
#else
        let estimate = screenTime.usageEstimate(
            forLimitMinutes: selectedMinutes
        )
        var notices: [HomeNotice] = []

        if estimate.unavailableReason == .timeZoneChanged {
            notices.append(Self.timeZoneNotice)
        }

        if isFirstMeasurementDay {
            notices.append(Self.firstDayNotice)
        }

        return notices
#endif
    }

    private var isFirstMeasurementDay: Bool {
        let startedAt = screenTime.usageSnapshot.monitoringStartedAt
        guard startedAt > 0 else { return false }
        return startedAt >= Calendar.autoupdatingCurrent
            .startOfDay(for: .now)
            .timeIntervalSince1970
    }

}

// Keep ownership of the sheet on a UIKit container, outside the SwiftUI
// hierarchy that embeds DeviceActivityReport's remote view controller.
private struct DailyLimitSheetPresenter: UIViewControllerRepresentable {
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
            configuration?.screenTime.cancelDailyLimitPreview()
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
    private let originalLimitMinutes: Int

    init(
        screenTime: ScreenTimeManager,
        windStrength: Binding<Double>,
        onSaved: @escaping () -> Void
    ) {
        self.onSaved = onSaved
        self.screenTime = screenTime
        _windStrength = windStrength
        _selectedMinutes = State(initialValue: screenTime.dailyLimitMinutes)
        originalLimitMinutes = screenTime.dailyLimitMinutes
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
                    onValueChange: screenTime.previewDailyLimit,
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

    private var formattedOriginalLimit: String {
        let hours = originalLimitMinutes / 60
        let minutes = originalLimitMinutes % 60
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

#if DEBUG
struct HomeScreenPreview: View {
    @StateObject private var screenTime: ScreenTimeManager
    @State private var windStrength = 0.25
    @State private var petalSimulationTime = 0.0
    @State private var petalFlow = SakuraPetalFlowState()

    init() {
        let suiteName = "HomeScreenPreview"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)

        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(
            2 * 60 * 60,
            forKey: AppConfiguration.DefaultsKey.dailyLimit
        )
        defaults.set(
            45 * 60,
            forKey: AppConfiguration.DefaultsKey.estimatedUsedTime
        )
        defaults.set(
            today.timeIntervalSince1970,
            forKey: AppConfiguration.DefaultsKey.lastCheckpointResetDay
        )
        defaults.set(
            calendar.timeZone.identifier,
            forKey: AppConfiguration.DefaultsKey
                .lastCheckpointTimeZoneIdentifier
        )
        defaults.set(
            today.addingTimeInterval(-60).timeIntervalSince1970,
            forKey: AppConfiguration.DefaultsKey.usageMonitoringStartedAt
        )
        defaults.set(
            true,
            forKey: AppConfiguration.DefaultsKey.hasUsageCheckpoint
        )

        _screenTime = StateObject(
            wrappedValue: ScreenTimeManager(defaults: defaults)
        )
    }

    var body: some View {
        ZStack {
            SakuraBackground()

            HomeScreen(
                screenTime: screenTime,
                windStrength: $windStrength,
                petalSimulationTime: $petalSimulationTime,
                petalFlow: $petalFlow,
                petalsStartFilled: true,
                showsPetals: true
            )
        }
    }
}

#Preview("Home") {
    HomeScreenPreview()
}

#endif
