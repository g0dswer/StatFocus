// StatFocus/Models/AppSettings.swift
import Foundation
import Combine

enum FocusBlockMode: String, CaseIterable, Identifiable {
    case app
    case website

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .app: return "settings.blocker.mode.app"
        case .website: return "settings.blocker.mode.website"
        }
    }

    var title: String { L.t(titleKey) }
}

enum BlockerStrictness: String, CaseIterable, Identifiable {
    case strict
    case soft

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .strict: return "settings.blocker.strictness.strict"
        case .soft:   return "settings.blocker.strictness.soft"
        }
    }
}

enum FocusBrowser: String, CaseIterable, Identifiable {
    case safari = "com.apple.Safari"
    case chrome = "com.google.Chrome"
    case edge = "com.microsoft.edgemac"
    case arc = "company.thebrowser.Browser"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .safari: return "Safari"
        case .chrome: return "Google Chrome"
        case .edge: return "Microsoft Edge"
        case .arc: return "Arc"
        }
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var focusDuration: Int {
        didSet { UserDefaults.standard.set(focusDuration, forKey: "focusDuration") }
    }
    @Published var shortBreakDuration: Int {
        didSet { UserDefaults.standard.set(shortBreakDuration, forKey: "shortBreakDuration") }
    }
    @Published var autoHideDuringFocus: Bool {
        didSet { UserDefaults.standard.set(autoHideDuringFocus, forKey: "autoHideDuringFocus") }
    }
    @Published var dailyGoalHours: Double {
        didSet { UserDefaults.standard.set(dailyGoalHours, forKey: "dailyGoalHours") }
    }
    @Published var weeklyGoalHours: Double {
        didSet { UserDefaults.standard.set(weeklyGoalHours, forKey: "weeklyGoalHours") }
    }
    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }
    @Published var totalFocusEnabled: Bool {
        didSet { UserDefaults.standard.set(totalFocusEnabled, forKey: "totalFocusEnabled") }
    }
    @Published var focusBlockerEnabled: Bool {
        didSet { UserDefaults.standard.set(focusBlockerEnabled, forKey: "focusBlockerEnabled") }
    }
    @Published var blockerStrictnessRaw: String {
        didSet { UserDefaults.standard.set(blockerStrictnessRaw, forKey: "blockerStrictnessRaw") }
    }
    @Published var focusBlockModeRaw: String {
        didSet { UserDefaults.standard.set(focusBlockModeRaw, forKey: "focusBlockModeRaw") }
    }
    @Published var focusBlockAllowedAppName: String {
        didSet { UserDefaults.standard.set(focusBlockAllowedAppName, forKey: "focusBlockAllowedAppName") }
    }
    @Published var focusBlockAllowedAppBundleID: String {
        didSet { UserDefaults.standard.set(focusBlockAllowedAppBundleID, forKey: "focusBlockAllowedAppBundleID") }
    }
    @Published var focusBlockAllowedWebsiteHost: String {
        didSet { UserDefaults.standard.set(focusBlockAllowedWebsiteHost, forKey: "focusBlockAllowedWebsiteHost") }
    }
    @Published var focusBlockBrowserBundleID: String {
        didSet { UserDefaults.standard.set(focusBlockBrowserBundleID, forKey: "focusBlockBrowserBundleID") }
    }

    /// Timestamp of the first time the app was launched on this device.
    /// Set once; never overwritten. Used to compute the free-trial window.
    private(set) var firstLaunchAt: Date

    var focusBlockMode: FocusBlockMode {
        get { FocusBlockMode(rawValue: focusBlockModeRaw) ?? .app }
        set { focusBlockModeRaw = newValue.rawValue }
    }

    var blockerStrictness: BlockerStrictness {
        get { BlockerStrictness(rawValue: blockerStrictnessRaw) ?? .strict }
        set { blockerStrictnessRaw = newValue.rawValue }
    }

    var focusBlockBrowser: FocusBrowser {
        get { FocusBrowser(rawValue: focusBlockBrowserBundleID) ?? .safari }
        set { focusBlockBrowserBundleID = newValue.rawValue }
    }

    private init() {
        let ud = UserDefaults.standard
        focusDuration = ud.integer(forKey: "focusDuration").nonZero ?? 25
        shortBreakDuration = ud.integer(forKey: "shortBreakDuration").nonZero ?? 5
        autoHideDuringFocus = ud.object(forKey: "autoHideDuringFocus") as? Bool ?? false
        dailyGoalHours = ud.double(forKey: "dailyGoalHours").nonZero ?? 4.0
        weeklyGoalHours = ud.double(forKey: "weeklyGoalHours").nonZero ?? 20.0
        soundEnabled = ud.object(forKey: "soundEnabled") as? Bool ?? true
        totalFocusEnabled = ud.object(forKey: "totalFocusEnabled") as? Bool ?? false
        focusBlockerEnabled = ud.object(forKey: "focusBlockerEnabled") as? Bool ?? false
        blockerStrictnessRaw = ud.string(forKey: "blockerStrictnessRaw") ?? BlockerStrictness.strict.rawValue
        focusBlockModeRaw = ud.string(forKey: "focusBlockModeRaw") ?? FocusBlockMode.app.rawValue
        focusBlockAllowedAppName = ud.string(forKey: "focusBlockAllowedAppName") ?? ""
        focusBlockAllowedAppBundleID = ud.string(forKey: "focusBlockAllowedAppBundleID") ?? ""
        focusBlockAllowedWebsiteHost = ud.string(forKey: "focusBlockAllowedWebsiteHost") ?? ""
        focusBlockBrowserBundleID = ud.string(forKey: "focusBlockBrowserBundleID") ?? FocusBrowser.safari.rawValue

        // First-launch timestamp — set once, never overwritten.
        if let storedFirst = ud.object(forKey: "firstLaunchAt") as? Date {
            firstLaunchAt = storedFirst
        } else {
            let now = Date()
            firstLaunchAt = now
            ud.set(now, forKey: "firstLaunchAt")
        }
    }

    func normalizedBlockedWebsiteHost() -> String {
        var value = focusBlockAllowedWebsiteHost
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        value = value.replacingOccurrences(of: "https://", with: "")
        value = value.replacingOccurrences(of: "http://", with: "")
        if let slash = value.firstIndex(of: "/") {
            value = String(value[..<slash])
        }
        return value
    }
}

final class TotalFocusState: ObservableObject {
    static let shared = TotalFocusState()

    @Published private(set) var isLockActive: Bool = false

    private init() {}

    func setLockActive(_ active: Bool) {
        guard isLockActive != active else { return }
        isLockActive = active
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
