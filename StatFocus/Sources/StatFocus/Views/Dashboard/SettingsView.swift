// StatFocus/Views/Dashboard/SettingsView.swift
import SwiftUI
import ServiceManagement
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var backupManager = BackupManager.shared
    @ObservedObject private var totalFocusState = TotalFocusState.shared
    @State private var showClearDataConfirmation = false
    private let loc = LocalizationManager.shared

    var body: some View {
        Form {
            if totalFocusState.isLockActive {
                Section(loc.t("settings.section.total_focus_active")) {
                    Text(loc.t("settings.total_focus_lock_message"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Section(loc.t("settings.section.timer")) {
                Stepper(
                    String(format: loc.t("settings.timer.focus_minutes"), settings.focusDuration),
                    value: $settings.focusDuration,
                    in: 5...90,
                    step: 5
                )
                Stepper(
                    String(format: loc.t("settings.timer.break_minutes"), settings.shortBreakDuration),
                    value: $settings.shortBreakDuration,
                    in: 1...30,
                    step: 1
                )
            }

            Section(loc.t("settings.section.goals")) {
                HStack {
                    Text(loc.t("settings.goals.daily"))
                    Spacer()
                    TextField(loc.t("settings.goals.hours_unit"), value: $settings.dailyGoalHours, format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                    Text(loc.t("settings.goals.hours_unit"))
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text(loc.t("settings.goals.weekly"))
                    Spacer()
                    TextField(loc.t("settings.goals.hours_unit"), value: $settings.weeklyGoalHours, format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                    Text(loc.t("settings.goals.hours_unit"))
                        .foregroundColor(.secondary)
                }
            }

            Section(loc.t("settings.section.general")) {
                Toggle(loc.t("settings.general.sound"), isOn: $settings.soundEnabled)
                Toggle(loc.t("settings.general.auto_hide"), isOn: $settings.autoHideDuringFocus)
                Toggle(loc.t("settings.general.total_focus"), isOn: $settings.totalFocusEnabled)
                Text(loc.t("settings.general.total_focus_help"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text(loc.t("settings.general.auto_show_help"))
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Toggle(loc.t("settings.general.start_at_login"), isOn: Binding(
                    get: {
                        SMAppService.mainApp.status == .enabled
                    },
                    set: { shouldEnable in
                        do {
                            if shouldEnable {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("SMAppService error: \(error)")
                        }
                    }
                ))
            }

            #if !APP_STORE
            Section(loc.t("settings.section.notifications")) {
                Text(loc.t("settings.notifications.help1"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text(loc.t("settings.notifications.help2"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            #endif

            Section(loc.t("settings.section.blocker")) {
                Toggle(loc.t("settings.blocker.enable"), isOn: $settings.focusBlockerEnabled)

                #if !APP_STORE
                Picker(loc.t("settings.blocker.strictness"), selection: Binding(
                    get: { settings.blockerStrictness },
                    set: { settings.blockerStrictness = $0 }
                )) {
                    ForEach(BlockerStrictness.allCases) { s in
                        Text(loc.t(s.titleKey)).tag(s)
                    }
                }
                .pickerStyle(.segmented)

                Text(loc.t("settings.blocker.strictness.help"))
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Picker(loc.t("settings.blocker.mode"), selection: Binding(
                    get: { settings.focusBlockMode },
                    set: { settings.focusBlockMode = $0 }
                )) {
                    ForEach(FocusBlockMode.allCases) { mode in
                        Text(loc.t(mode.titleKey)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if settings.focusBlockMode == .app {
                    HStack {
                        Text(loc.t("settings.blocker.allowed_app"))
                        Spacer()
                        Text(settings.focusBlockAllowedAppName.isEmpty ? loc.t("settings.blocker.allowed_app.none") : settings.focusBlockAllowedAppName)
                            .foregroundColor(.secondary)
                    }
                    Button(loc.t("settings.blocker.select_app")) {
                        selectAllowedApp()
                    }
                } else {
                    HStack {
                        Text(loc.t("settings.blocker.allowed_website"))
                        Spacer()
                        TextField(loc.t("settings.blocker.website_placeholder"), text: $settings.focusBlockAllowedWebsiteHost)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 200)
                    }

                    Picker(loc.t("settings.blocker.browser"), selection: Binding(
                        get: { settings.focusBlockBrowser },
                        set: { settings.focusBlockBrowser = $0 }
                    )) {
                        ForEach(FocusBrowser.allCases) { browser in
                            Text(browser.title).tag(browser)
                        }
                    }
                }
                #else
                // App Store build: only soft-block + app mode. Friendly banner appears
                // when the user switches away from the allowed app during focus.
                HStack {
                    Text(loc.t("settings.blocker.allowed_app"))
                    Spacer()
                    Text(settings.focusBlockAllowedAppName.isEmpty ? loc.t("settings.blocker.allowed_app.none") : settings.focusBlockAllowedAppName)
                        .foregroundColor(.secondary)
                }
                Button(loc.t("settings.blocker.select_app")) {
                    selectAllowedApp()
                }
                #endif

                Text(loc.t("settings.blocker.help"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(loc.t("settings.section.data")) {
                Text(loc.t("settings.data.help"))
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Button(loc.t("settings.data.clear"), role: .destructive) {
                    showClearDataConfirmation = true
                }
            }

            Section(loc.t("settings.section.backup")) {
                Text(loc.t("settings.backup.help"))
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Toggle(loc.t("settings.backup.auto"), isOn: Binding(
                    get: { backupManager.autoBackupEnabled },
                    set: { newValue in
                        DispatchQueue.main.async {
                            backupManager.setAutoBackupEnabled(newValue)
                        }
                    }
                ))

                HStack {
                    Text(loc.t("settings.backup.folder"))
                    Spacer()
                    Text(
                        backupManager.backupFolderPath.isEmpty
                        ? loc.t("settings.backup.folder.none")
                        : backupManager.backupFolderPath
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                }

                HStack(spacing: 12) {
                    Button(loc.t("settings.backup.choose_folder")) {
                        backupManager.chooseBackupFolder()
                    }

                    Button(loc.t("settings.backup.now")) {
                        backupManager.createManualBackup()
                    }
                    .disabled(!backupManager.hasBackupFolderConfigured)

                    Button(loc.t("settings.backup.import")) {
                        backupManager.importBackupUsingPicker()
                    }
                }

                if let lastBackupAt = backupManager.lastBackupAt {
                    Text(String(format: loc.t("settings.backup.last"), lastBackupAt.formatted(date: .numeric, time: .shortened)))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                if !backupManager.statusMessage.isEmpty {
                    Text(backupManager.statusMessage)
                        .font(.footnote)
                        .foregroundColor(backupManager.statusIsError ? .red : .secondary)
                }
            }

            #if DEBUG
            Section(loc.t("settings.section.dev")) {
                Button(loc.t("settings.dev.seed")) {
                    NotificationCenter.default.post(
                        name: .init("SeedTestData"),
                        object: nil
                    )
                }
                .foregroundColor(.orange)
            }
            #endif
        }
        .formStyle(.grouped)
        .disabled(totalFocusState.isLockActive)
        .alert(loc.t("settings.data.clear_alert.title"), isPresented: $showClearDataConfirmation) {
            Button(loc.t("settings.data.clear_alert.cancel"), role: .cancel) {}
            Button(loc.t("settings.data.clear_alert.confirm"), role: .destructive) {
                SessionStore.shared.deleteAll()
                NotificationCenter.default.post(name: .sessionsUpdated, object: nil)
            }
        } message: {
            Text(loc.t("settings.data.clear_alert.message"))
        }
    }

    private func selectAllowedApp() {
        let panel = NSOpenPanel()
        panel.title = loc.t("settings.app_picker.title")
        panel.prompt = loc.t("settings.app_picker.prompt")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let bundle = Bundle(url: url)
        settings.focusBlockAllowedAppName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        settings.focusBlockAllowedAppBundleID = bundle?.bundleIdentifier ?? ""
    }
}
