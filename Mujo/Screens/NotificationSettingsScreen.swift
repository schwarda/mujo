import SwiftUI
import UserNotifications

struct NotificationSettingsScreen: View {
    private struct AlertEditor: Identifiable {
        let id = UUID()
        let percentage: Int?
    }

    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var screenTime: ScreenTimeManager
    @ObservedObject private var authorization: NotificationAuthorization
    @State private var preferences: NotificationPreferences
    @State private var editor: AlertEditor?
    @State private var isRequestingPermission = false
    @State private var permissionError: String?

    init(screenTime: ScreenTimeManager) {
        self.screenTime = screenTime
        authorization = screenTime.notificationAuthorization
        _preferences = State(initialValue: screenTime.notificationPreferences)
    }

    var body: some View {
        ZStack {
            OnboardingBackground()

            List {
                if !authorization.hasLoadedSettings {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                } else if authorization.isAuthorized {
                    alertsSection
                    customAlertsSection
                    badgesSection
                    if !screenTime.usesSimulatedData {
                        systemSettingsSection
                    }

                    if !screenTime.canSaveNotificationPreferences {
                        Section {
                            Text("Notification settings are unavailable. Try opening Mujø again.")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    permissionSection
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .tint(.accentColor)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar(.visible, for: .navigationBar)
        .background { PinkNavigationBackIndicator() }
        .task { await authorization.refreshStatus() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await authorization.refreshStatus()
                preferences = screenTime.notificationPreferences
                screenTime.refreshNotificationBadge()
            }
        }
        .onChange(of: authorization.isAuthorized) { _, allowed in
            if !allowed { editor = nil }
        }
        .onChange(of: preferences) { _, value in
            screenTime.saveNotificationPreferences(value)
            Task { await screenTime.refreshNotificationPreferences() }
        }
        .sheet(item: $editor) { item in
            CustomNotificationEditor(
                percentage: item.percentage
            ) { percentage in
                guard authorization.isAuthorized else { return }
                var values = preferences.customPercentages
                if let original = item.percentage {
                    values.removeAll { $0 == original }
                }
                values.append(percentage)
                preferences.customPercentages = NotificationPreferences
                    .validPercentages(values)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Notifications couldn’t be enabled", isPresented: Binding(
            get: { permissionError != nil },
            set: { if !$0 { permissionError = nil } }
        )) {
            Button("OK", role: .cancel) { permissionError = nil }
        } message: {
            Text(permissionError ?? "Please try again.")
        }
    }

    private var permissionSection: some View {
        Section {
            if authorization.status == .notDetermined {
                Button("Enable Notifications", action: requestPermission)
                    .disabled(isRequestingPermission)
            } else {
                Button("Open Settings", action: openSystemSettings)
            }
        } footer: {
            if authorization.status == .notDetermined {
                Text("Allow notifications to choose your alerts and show the app badge.")
            } else {
                Text("Notifications are off for Mujø. You can allow them in Settings.")
            }
        }
    }

    private var alertsSection: some View {
        Section {
            Toggle("Recommended", isOn: $preferences.recommendedEnabled)
                .accessibilityIdentifier("notifications-recommended")
            Toggle("Limit reached", isOn: $preferences.limitReachedEnabled)
                .accessibilityIdentifier("notifications-limit-reached")
        } header: {
            Text("Alerts")
        } footer: {
            Text("Recommended alerts remind you during the day and as you approach your limit.")
        }
        .disabled(!screenTime.canSaveNotificationPreferences)
    }

    private var customAlertsSection: some View {
        Section {
            ForEach(preferences.customPercentages, id: \.self) { percentage in
                Button {
                    editor = AlertEditor(percentage: percentage)
                } label: {
                    HStack {
                        Text("\(percentage)% used")
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("custom-alert-\(percentage)")
                .accessibilityAction(named: Text("Remove \(percentage)% alert")) {
                    removeCustomAlert(percentage)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Remove", role: .destructive) {
                        removeCustomAlert(percentage)
                    }
                    .accessibilityIdentifier("remove-custom-alert-\(percentage)")
                }
            }

            if preferences.customPercentages.count < 99 {
                Button("Add alert") {
                    editor = AlertEditor(percentage: nil)
                }
                .accessibilityIdentifier("add-custom-alert")
            }
        } header: {
            Text("Custom alerts")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                if let error = screenTime.errorMessage {
                    Text(error)
                }
            }
        }
        .disabled(!screenTime.canSaveNotificationPreferences)
    }

    private func removeCustomAlert(_ percentage: Int) {
        guard authorization.isAuthorized,
              screenTime.canSaveNotificationPreferences else { return }
        preferences.customPercentages.removeAll { $0 == percentage }
    }

    private var badgesSection: some View {
        Section {
            Toggle("Remaining minutes", isOn: $preferences.badgeEnabled)
                .accessibilityIdentifier("notifications-badge")
        } header: {
            Text("App badge")
        } footer: {
            Text("Show the time right top on the app icon.")
        }
        .disabled(!screenTime.canSaveNotificationPreferences)
    }

    private var systemSettingsSection: some View {
        Section {
            Button("Open Settings", action: openSystemSettings)
        } footer: {
            if authorization.status == .provisional {
                Text("Alerts are delivered quietly. You can change this in Settings.")
            } else if authorization.alertSetting == .disabled
                        && authorization.notificationCenterSetting == .disabled {
                Text("Banners and Notification Center are off in Settings.")
            } else {
                Text("Choose banners, sounds and other notification options in Settings.")
            }
            if authorization.badgeSetting == .disabled {
                Text("App badges are off in Settings.")
            }
        }
    }

    private func requestPermission() {
        guard !isRequestingPermission else { return }
        isRequestingPermission = true
        Task {
            let result = await authorization.requestAuthorization()
            isRequestingPermission = false
            if case .failed = result {
                permissionError = "Please try again, or allow notifications in Settings."
            }
            screenTime.refreshNotificationBadge()
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else {
            permissionError = "Settings couldn’t be opened. Please try again."
            return
        }
        UIApplication.shared.open(url) { opened in
            if !opened {
                Task { @MainActor in
                    permissionError = "Settings couldn’t be opened. Please try again."
                }
            }
        }
    }
}

private struct CustomNotificationEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var percentage: Int
    let onSave: (Int) -> Void

    init(percentage: Int?, onSave: @escaping (Int) -> Void) {
        _percentage = State(initialValue: percentage ?? 50)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SakuraBackground().ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        Text("Send an alert when you reach this percentage of your daily limit.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Picker("Daily limit used", selection: $percentage) {
                            ForEach(1...99, id: \.self) { value in
                                Text("\(value)%").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 170)
                        .accessibilityIdentifier("custom-alert-percentage")
                    }
                    .padding(24)
                    .frame(maxWidth: 420)
                    .frame(maxWidth: .infinity)
                }
            }
            .tint(MujoTheme.brandAccent)
            .navigationTitle("Custom alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("cancel-custom-alert")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        onSave(percentage)
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .mujoProminentGlassButtonStyle()
                    .accessibilityIdentifier("save-custom-alert")
                }
            }
        }
    }
}
