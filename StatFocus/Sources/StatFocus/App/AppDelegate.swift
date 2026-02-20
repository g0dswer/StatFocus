// StatFocus/App/AppDelegate.swift
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var timerPanel: NSPanel?
    var dashboardWindow: NSWindow?
    private var timerViewModel: TimerViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupTimerPanel()
        addGlobalKeyboardShortcut()
        setupSeedDataListener()
    }

    // MARK: - Timer Panel (floating, always-on-top)

    func setupTimerPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 220),
            styleMask: [
                .nonactivatingPanel,
                .titled,
                .closable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )
        panel.title = ""
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.hasShadow = true
        panel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.0)
        panel.center()

        let vm = TimerViewModel()
        self.timerViewModel = vm

        let content = TimerView(viewModel: vm, onOpenDashboard: { [weak self] in
            self?.openDashboard()
        })
        panel.contentView = NSHostingView(rootView: content)
        panel.makeKeyAndOrderFront(nil)
        self.timerPanel = panel
    }

    // MARK: - Dashboard Window

    func openDashboard() {
        if let existing = dashboardWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
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
        window.contentView = NSHostingView(rootView: dashView)
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
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
        guard let panel = timerPanel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
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
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === dashboardWindow {
            dashboardWindow = nil
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
