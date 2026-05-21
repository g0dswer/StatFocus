// StatFocus/Models/TrialState.swift
// Derives free-trial state from first-launch timestamp + purchase state.
// In Dev ID builds, isLocked is always false — IAP only exists on App Store.
import Foundation
import Observation

@Observable
final class TrialState {
    static let shared = TrialState()

    /// How many days of free use the user gets before being asked to pay.
    static let trialDays: Int = 7

    /// True when the user has unlocked the app via the App Store IAP.
    /// In Dev ID builds, this is always true (no IAP exists outside App Store).
    var isPremium: Bool {
        didSet {
            // Cache to UserDefaults so we don't have to wait for StoreKit on next launch
            UserDefaults.standard.set(isPremium, forKey: Self.premiumCacheKey)
        }
    }

    private let firstLaunchProvider: () -> Date
    private let nowProvider: () -> Date

    static let premiumCacheKey = "iap.premium.cached"

    init(
        firstLaunchProvider: @escaping () -> Date = { AppSettings.shared.firstLaunchAt },
        nowProvider: @escaping () -> Date = { Date() }
    ) {
        self.firstLaunchProvider = firstLaunchProvider
        self.nowProvider = nowProvider
        #if APP_STORE
        self.isPremium = UserDefaults.standard.bool(forKey: Self.premiumCacheKey)
        #else
        // Dev ID build: no IAP, app is always unlocked.
        self.isPremium = true
        #endif
    }

    // MARK: - Derived state

    /// Number of full calendar days remaining in the trial. Min 0.
    var daysRemaining: Int {
        let start = Calendar.autoupdatingCurrent.startOfDay(for: firstLaunchProvider())
        let today = Calendar.autoupdatingCurrent.startOfDay(for: nowProvider())
        let elapsedDays = Calendar.autoupdatingCurrent.dateComponents([.day], from: start, to: today).day ?? 0
        return max(0, Self.trialDays - elapsedDays)
    }

    /// True while the user is inside the free-trial window AND has not bought premium.
    var isInTrial: Bool {
        !isPremium && daysRemaining > 0
    }

    /// True when the trial expired and the user has NOT bought premium.
    /// App UI should overlay a paywall in this state.
    var isLocked: Bool {
        !isPremium && daysRemaining <= 0
    }
}
