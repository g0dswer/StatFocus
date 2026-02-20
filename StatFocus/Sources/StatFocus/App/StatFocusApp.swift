// StatFocus/App/StatFocusApp.swift
import SwiftUI

@main
struct StatFocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // All window management is done in AppDelegate.
        // We need at least one scene for the @main entry point.
        Settings {
            EmptyView()
        }
    }
}
