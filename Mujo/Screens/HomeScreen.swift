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

    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var screenTime: ScreenTimeManager

    @Binding var windStrength: Double
    @Binding var petalSimulationTime: Double
    @Binding var petalFlow: SakuraPetalFlowState
    let petalsStartFilled: Bool
    let showsPetals: Bool

    @State private var isShowingLimitEditor = false
    @State private var isShowingAppInfo = false
    @State private var noticeGeometries: [HomeNotice.ID: HomeNoticeGeometry] = [:]

#if DEBUG
    @State private var isShowingDiagnostics = false
    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = true
#endif

    var body: some View {
        NavigationStack {
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
                    .padding(.bottom, 34)

                }

                homeMenu

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
                .padding(.top, 60)
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
            .navigationDestination(isPresented: $isShowingAppInfo) {
                AppInfoScreen()
            }
#if DEBUG
            .sheet(isPresented: $isShowingDiagnostics) {
                DiagnosticsView(screenTime: screenTime)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
#endif
        }
    }

    private var homeMenu: some View {
        VStack {
            HStack {
                Menu {
                    Button {
                        isShowingAppInfo = true
                    } label: {
                        Label("App Info", systemImage: "info.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .rotationEffect(.degrees(90))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.clear.interactive(), in: .circle)
                .foregroundStyle(.tint)
                .accessibilityLabel("Menu")

                Spacer()
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var selectedMinutes: Int {
        screenTime.dailyLimitMinutes
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
                Text(usageSummary(usedTime: estimate.usedTime))
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

    private func usageSummary(usedTime: TimeInterval) -> String {
        let formattedLimit = OnboardingDurationFormatter.string(
            minutes: selectedMinutes
        )
        let formattedUsedTime = OnboardingDurationFormatter.string(
            minutes: Int(usedTime) / 60
        )
        return "\(formattedUsedTime) used · \(formattedLimit) limit"
    }

    private var homeNotices: [HomeNotice] {
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
    }

    private var isFirstMeasurementDay: Bool {
        let startedAt = screenTime.usageSnapshot.monitoringStartedAt
        guard startedAt > 0 else { return false }
        return startedAt >= Calendar.autoupdatingCurrent
            .startOfDay(for: .now)
            .timeIntervalSince1970
    }

}
