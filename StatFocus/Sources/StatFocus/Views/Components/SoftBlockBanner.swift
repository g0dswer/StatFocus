// StatFocus/Views/Components/SoftBlockBanner.swift
// Non-activating floating panel used for "soft" blocker violations.
// Appears top-center of the main screen, auto-hides after a few seconds.
import AppKit
import SwiftUI

/// Lifetime-managed panel + auto-hide timer.
@MainActor
final class SoftBlockBannerController {
    static let shared = SoftBlockBannerController()

    private let displayDuration: TimeInterval = 4.0
    private let panelWidth: CGFloat = 320
    private let panelHeight: CGFloat = 64

    private var panel: NSPanel?
    private let content = SoftBlockBannerContent()
    private var hideTask: DispatchWorkItem?

    func show(violatedAppName: String) {
        content.violatedAppName = violatedAppName
        content.shownAt = Date()

        ensurePanel()
        positionAtTopCenter()
        panel?.orderFrontRegardless()

        hideTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.panel?.orderOut(nil)
        }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration, execute: task)
    }

    private func ensurePanel() {
        guard panel == nil else { return }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.hidesOnDeactivate = false
        p.becomesKeyOnlyIfNeeded = true
        p.isMovableByWindowBackground = false
        p.contentView = NSHostingView(rootView: SoftBlockBannerView(content: content))
        panel = p
    }

    private func positionAtTopCenter() {
        guard let panel else { return }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let x = visible.midX - panelWidth / 2
        // Place ~20pt below the top of the visible area (so it hugs the menu bar gap).
        let y = visible.maxY - panelHeight - 20
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }
}

/// Tiny observable content holder so SwiftUI re-renders when the violated app changes.
final class SoftBlockBannerContent: ObservableObject {
    @Published var violatedAppName: String = ""
    @Published var shownAt: Date = .distantPast
}

struct SoftBlockBannerView: View {
    @ObservedObject var content: SoftBlockBannerContent
    private let loc = LocalizationManager.shared
    private let accent = Color(hex: "#2D6A4F")

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(loc.t("blocker.soft.title"))
                    .font(.system(size: 13, weight: .semibold))
                Text(String(format: loc.t("blocker.soft.message"), content.violatedAppName))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        // Re-trigger transition on every show by binding to shownAt.
        .id(content.shownAt)
        .transition(.opacity)
    }
}
