// StatFocus/Views/Components/TrialBanner.swift
// Subtle countdown banner shown at the top of the dashboard while in trial.
// Tappable → opens the paywall.
#if APP_STORE
import SwiftUI

struct TrialBanner: View {
    let trial: TrialState
    let onBuy: () -> Void
    private let loc = LocalizationManager.shared
    private let accent = Color(hex: "#2D6A4F")

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark.fill")
                .foregroundColor(accent)
                .font(.system(size: 13, weight: .medium))

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)

            Spacer(minLength: 0)

            Button(action: onBuy) {
                Text(loc.t("trial.banner.cta"))
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(accent)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(accent.opacity(0.08))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(accent.opacity(0.15)),
            alignment: .bottom
        )
    }

    private var message: String {
        let days = trial.daysRemaining
        if days == 1 {
            return loc.t("trial.banner.days_one")
        }
        return String(format: loc.t("trial.banner.days_many"), days)
    }
}
#endif
