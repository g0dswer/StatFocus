// StatFocus/App/AppDelegate.swift
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var timerPanel: NSWindow?
    var dashboardWindow: NSWindow?
    private var timerViewModel: TimerViewModel?
    private var backupManager: BackupManager?
    private var timerLifecycleObservers: [NSObjectProtocol] = []
    private let focusBlocker = FocusBlockerController()
    private var focusBlockerTimer: Timer?
    #if !APP_STORE
    private let notificationSuppressor = SystemNotificationSuppressor()
    private var notificationSuppressionState = false
    private var didShowNotificationSetupAlert = false
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        backupManager = BackupManager.shared
        setupTimerPanel()
        addGlobalKeyboardShortcut()
        setupTimerLifecycleListeners()
        setupFocusBlocker()
        setupSeedDataListener()
        showTimerPanel(bringToFront: true)

        #if APP_STORE
        // Eagerly refresh purchase entitlements + load product so the paywall has
        // localized price ready when the user first sees it.
        Task { @MainActor in
            await StoreManager.shared.refreshEntitlements()
            await StoreManager.shared.loadProducts()
        }
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if TotalFocusState.shared.isLockActive {
            showTimerPanel(bringToFront: true)
            return .terminateCancel
        }
        return .terminateNow
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        let timerVisible = timerPanel?.isVisible ?? false
        let dashboardVisible = dashboardWindow?.isVisible ?? false
        if !timerVisible && !dashboardVisible {
            showTimerPanel(bringToFront: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        #if !APP_STORE
        if notificationSuppressionState {
            _ = notificationSuppressor.setSuppressed(false)
            notificationSuppressionState = false
        }
        #endif
    }

    // MARK: - Timer Panel (floating, always-on-top)

    func setupTimerPanel() {
        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 250),
            styleMask: [
                .titled,
                .closable,
                .resizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )
        panel.title = ""
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = true
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.minSize = NSSize(width: 300, height: 220)
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.delegate = self
        panel.center()

        let vm = TimerViewModel()
        self.timerViewModel = vm

        let content = TimerView(viewModel: vm, onOpenDashboard: { [weak self] in
            self?.openDashboard()
        }, onCloseTimer: { [weak self] in
            self?.hideTimerPanel()
        })
        panel.contentViewController = NSHostingController(rootView: content)
        self.timerPanel = panel
    }

    // MARK: - Dashboard Window

    func openDashboard() {
        if let existing = dashboardWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "StatFocus"
        window.center()
        window.delegate = self
        window.minSize = NSSize(width: 700, height: 500)

        let statsVM = StatsViewModel()
        let dashView = DashboardView(statsViewModel: statsVM)
        window.contentViewController = NSHostingController(rootView: dashView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.dashboardWindow = window
    }

    // MARK: - Keyboard shortcut Cmd+Shift+F → toggle timer

    private func addGlobalKeyboardShortcut() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // keyCode 3 = 'f'
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 3 {
                DispatchQueue.main.async { self?.toggleTimerPanel() }
            }
        }
    }

    func toggleTimerPanel() {
        ensureTimerWindowExists()
        guard let panel = timerPanel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            showTimerPanel(bringToFront: true)
        }
    }

    func hideTimerPanel() {
        guard !TotalFocusState.shared.isLockActive else {
            showTimerPanel(bringToFront: true)
            return
        }
        timerPanel?.orderOut(nil)
    }

    @discardableResult
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showTimerPanel(bringToFront: true)
        } else {
            if let dashboard = dashboardWindow, dashboard.isVisible {
                dashboard.makeKeyAndOrderFront(nil)
            } else {
                showTimerPanel(bringToFront: true)
            }
        }
        return true
    }

    private func showTimerPanel(bringToFront: Bool) {
        ensureTimerWindowExists()
        guard let panel = timerPanel else { return }
        ensureWindowIsVisibleOnScreen(panel)
        if bringToFront {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.makeMain()
            panel.orderFrontRegardless()
        } else {
            panel.orderFront(nil)
        }
    }

    private func ensureTimerWindowExists() {
        if timerPanel == nil {
            setupTimerPanel()
        }
    }

    private func ensureWindowIsVisibleOnScreen(_ window: NSWindow) {
        let visibleOnAnyScreen = NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(window.frame)
        }
        guard !visibleOnAnyScreen else { return }

        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let targetSize = window.frame.size
            let newOrigin = NSPoint(
                x: screen.visibleFrame.midX - targetSize.width / 2,
                y: screen.visibleFrame.midY - targetSize.height / 2
            )
            window.setFrameOrigin(newOrigin)
        } else {
            window.center()
        }
    }

    // MARK: - Focus blocker

    private func setupFocusBlocker() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.enforceFocusBlockerIfNeeded()
        }
        RunLoop.main.add(timer, forMode: .common)
        focusBlockerTimer = timer
    }

    private func enforceFocusBlockerIfNeeded() {
        guard let vm = timerViewModel else { return }
        #if !APP_STORE
        let shouldSuppressNotifications = vm.timerState == .running && vm.phase == .focus
        applyNotificationSuppressionIfNeeded(shouldSuppress: shouldSuppressNotifications)
        #endif

        let focusIsActive = vm.timerState == .running && vm.phase == .focus
        guard focusIsActive else {
            focusBlocker.resetState()
            return
        }

        let settings = AppSettings.shared
        let strictMode = TotalFocusState.shared.isLockActive
        let shouldEnforce = settings.focusBlockerEnabled || strictMode
        guard shouldEnforce else { return }

        focusBlocker.enforce(settings: settings, strictMode: strictMode) { [weak self] in
            self?.showTimerPanel(bringToFront: true)
        }
    }

    #if !APP_STORE
    private func applyNotificationSuppressionIfNeeded(shouldSuppress: Bool) {
        guard shouldSuppress != notificationSuppressionState else { return }
        let result = notificationSuppressor.setSuppressed(shouldSuppress)
        notificationSuppressionState = shouldSuppress

        if shouldSuppress, case .failed = result, !didShowNotificationSetupAlert {
            didShowNotificationSetupAlert = true
            showNotificationSetupAlert()
        }
    }

    private func showNotificationSetupAlert() {
        let alert = NSAlert()
        alert.messageText = L.t("alert.notif_setup.title")
        alert.informativeText = L.t("alert.notif_setup.message")
        alert.addButton(withTitle: L.t("alert.notif_setup.open_shortcuts"))
        alert.addButton(withTitle: L.t("alert.notif_setup.later"))
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
        }
    }
    #endif

    // MARK: - Timer lifecycle UI automation

    private func setupTimerLifecycleListeners() {
        let focusStarted = NotificationCenter.default.addObserver(
            forName: .focusTimerStarted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard AppSettings.shared.autoHideDuringFocus else { return }
            self?.hideTimerPanel()
        }

        let focusEndingSoon = NotificationCenter.default.addObserver(
            forName: .focusTimerEndingSoon,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard AppSettings.shared.autoHideDuringFocus else { return }
            self?.showTimerPanel(bringToFront: true)
        }

        timerLifecycleObservers = [focusStarted, focusEndingSoon]
    }

    // MARK: - Debug: seed test data

    private func setupSeedDataListener() {
        #if DEBUG
        NotificationCenter.default.addObserver(
            forName: .init("SeedTestData"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.timerViewModel?.seedTestData()
        }
        #endif
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if TotalFocusState.shared.isLockActive && sender === timerPanel {
            showTimerPanel(bringToFront: true)
            return false
        }
        if sender === timerPanel {
            timerPanel?.orderOut(nil)
            return false
        }
        if sender === dashboardWindow {
            dashboardWindow?.orderOut(nil)
            return false
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === dashboardWindow {
            dashboardWindow = nil
        }
    }
}

private final class FocusBlockerController {
    private var lastViolationAt: Date = .distantPast
    private var lastWebsiteRedirectAt: Date = .distantPast
    private var isHandlingViolation = false
    private var appBundleID: String { Bundle.main.bundleIdentifier ?? "com.thiagogruber.statfocus" }

    func resetState() {
        lastViolationAt = .distantPast
        lastWebsiteRedirectAt = .distantPast
    }

    func enforce(settings: AppSettings, strictMode: Bool, onViolation: () -> Void) {
        guard !isHandlingViolation else { return }
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }

        let frontBundleID = frontApp.bundleIdentifier ?? ""
        if frontBundleID == appBundleID { return }

        #if APP_STORE
        // App Store: sandbox forbids hide/activate/AppleScript. Soft mode only,
        // app mode only (no website blocking until Network Extension lands).
        let effectivelyStrict = false
        enforceAppMode(settings: settings, frontApp: frontApp, strict: effectivelyStrict, onViolation: onViolation)
        #else
        // Foco Total always forces strict; otherwise use user's chosen strictness.
        let effectivelyStrict = strictMode || settings.blockerStrictness == .strict

        switch settings.focusBlockMode {
        case .app:
            enforceAppMode(settings: settings, frontApp: frontApp, strict: effectivelyStrict, onViolation: onViolation)
        case .website:
            enforceWebsiteMode(settings: settings, frontApp: frontApp, strict: effectivelyStrict, onViolation: onViolation)
        }
        #endif
    }

    private func enforceAppMode(settings: AppSettings, frontApp: NSRunningApplication, strict: Bool, onViolation: () -> Void) {
        let allowedBundleID = settings.focusBlockAllowedAppBundleID
        guard !allowedBundleID.isEmpty else {
            triggerViolation(frontApp: frontApp, activateBundleID: strict ? appBundleID : nil, strict: strict, onViolation: onViolation)
            return
        }

        guard frontApp.bundleIdentifier != allowedBundleID else { return }
        triggerViolation(frontApp: frontApp, activateBundleID: allowedBundleID, strict: strict, onViolation: onViolation)
    }

    #if !APP_STORE
    private func enforceWebsiteMode(settings: AppSettings, frontApp: NSRunningApplication, strict: Bool, onViolation: () -> Void) {
        let allowedHost = settings.normalizedBlockedWebsiteHost()
        let browserBundleID = settings.focusBlockBrowserBundleID

        guard !allowedHost.isEmpty else {
            triggerViolation(frontApp: frontApp, activateBundleID: strict ? appBundleID : nil, strict: strict, onViolation: onViolation)
            return
        }

        guard frontApp.bundleIdentifier == browserBundleID else {
            if strict {
                redirectBrowserIfNeeded(bundleID: browserBundleID, allowedHost: allowedHost)
            }
            triggerViolation(frontApp: frontApp, activateBundleID: browserBundleID, strict: strict, onViolation: onViolation)
            return
        }

        guard let currentHost = currentBrowserHost(bundleID: browserBundleID),
              host(currentHost, matchesAllowedHost: allowedHost) else {
            if strict {
                redirectBrowserIfNeeded(bundleID: browserBundleID, allowedHost: allowedHost)
            }
            triggerViolation(frontApp: frontApp, activateBundleID: browserBundleID, strict: strict, onViolation: onViolation)
            return
        }
    }
    #endif

    private func triggerViolation(frontApp: NSRunningApplication, activateBundleID: String?, strict: Bool, onViolation: () -> Void) {
        let now = Date()
        guard now.timeIntervalSince(lastViolationAt) >= 0.8 else { return }
        lastViolationAt = now

        isHandlingViolation = true
        defer { isHandlingViolation = false }

        #if !APP_STORE
        if strict {
            frontApp.hide()
            if let activateBundleID {
                activateApp(bundleID: activateBundleID)
            }
            onViolation()
            return
        }
        #endif

        // Soft block (only path in App Store build).
        let name = frontApp.localizedName ?? frontApp.bundleIdentifier ?? "?"
        Task { @MainActor in
            SoftBlockBannerController.shared.show(violatedAppName: name)
        }
    }

    #if !APP_STORE
    private func activateApp(bundleID: String) {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            running.activate(options: [.activateAllWindows])
            return
        }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
    }

    private func redirectBrowserIfNeeded(bundleID: String, allowedHost: String) {
        let now = Date()
        guard now.timeIntervalSince(lastWebsiteRedirectAt) >= 2 else { return }
        lastWebsiteRedirectAt = now

        let appName = browserAppName(bundleID: bundleID)
        let script = browserRedirectScript(appName: appName, host: allowedHost)
        _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
    }

    private func currentBrowserHost(bundleID: String) -> String? {
        let appName = browserAppName(bundleID: bundleID)
        let script = browserCurrentURLScript(appName: appName)
        guard let result = NSAppleScript(source: script)?.executeAndReturnError(nil).stringValue else {
            return nil
        }
        guard let host = URL(string: result)?.host?.lowercased() else { return nil }
        return host
    }

    private func host(_ host: String, matchesAllowedHost allowedHost: String) -> Bool {
        host == allowedHost || host.hasSuffix(".\(allowedHost)")
    }

    private func browserAppName(bundleID: String) -> String {
        switch bundleID {
        case FocusBrowser.chrome.rawValue: return "Google Chrome"
        case FocusBrowser.edge.rawValue: return "Microsoft Edge"
        case FocusBrowser.arc.rawValue: return "Arc"
        default: return "Safari"
        }
    }

    private func browserCurrentURLScript(appName: String) -> String {
        if appName == "Safari" {
            return """
            tell application "\(appName)"
                if (count of windows) is 0 then return ""
                return URL of current tab of front window
            end tell
            """
        }
        return """
        tell application "\(appName)"
            if (count of windows) is 0 then return ""
            return URL of active tab of front window
        end tell
        """
    }

    private func browserRedirectScript(appName: String, host: String) -> String {
        let url = "https://\(host)"
        if appName == "Safari" {
            return """
            tell application "\(appName)"
                activate
                if (count of windows) is 0 then make new document
                set URL of current tab of front window to "\(url)"
            end tell
            """
        }
        return """
        tell application "\(appName)"
            activate
            if (count of windows) is 0 then make new window
            set URL of active tab of front window to "\(url)"
        end tell
        """
    }
    #endif
}

#if !APP_STORE
private enum NotificationSuppressionResult {
    case success
    case failed
}

private final class SystemNotificationSuppressor {
    private let shortcutsBinary = "/usr/bin/shortcuts"
    private let defaultsBinary = "/usr/bin/defaults"
    private let killallBinary = "/usr/bin/killall"
    private let shortcutOff = "StatFocus - Notificacoes OFF"
    private let shortcutOn = "StatFocus - Notificacoes ON"

    func setSuppressed(_ suppressed: Bool) -> NotificationSuppressionResult {
        let shortcut = suppressed ? shortcutOff : shortcutOn
        let result = runShortcut(named: shortcut)
        if result == .success {
            return .success
        }

        // Fallback: toggle Do Not Disturb directly for the current user session.
        if setDoNotDisturbFallback(enabled: suppressed) {
            return .success
        }

        return .failed
    }

    @discardableResult
    private func runShortcut(named name: String) -> NotificationSuppressionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shortcutsBinary)
        process.arguments = ["run", name]
        let errPipe = Pipe()
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? .success : .failed
        } catch {
            return .failed
        }
    }

    private func setDoNotDisturbFallback(enabled: Bool) -> Bool {
        let boolValue = enabled ? "true" : "false"

        let write = Process()
        write.executableURL = URL(fileURLWithPath: defaultsBinary)
        write.arguments = ["-currentHost", "write", "com.apple.notificationcenterui", "doNotDisturb", "-boolean", boolValue]
        write.standardError = Pipe()

        do {
            try write.run()
            write.waitUntilExit()
            guard write.terminationStatus == 0 else { return false }
        } catch {
            return false
        }

        // Refresh Notification Center to apply immediately.
        let restart = Process()
        restart.executableURL = URL(fileURLWithPath: killallBinary)
        restart.arguments = ["NotificationCenter"]
        restart.standardError = Pipe()
        do {
            try restart.run()
            restart.waitUntilExit()
        } catch {
            // Best effort: preference was written even if process restart failed.
        }
        return true
    }

}
#endif
