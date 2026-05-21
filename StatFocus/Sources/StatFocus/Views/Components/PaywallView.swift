// StatFocus/Views/Components/PaywallView.swift
// Fullscreen paywall shown when the trial expired and the user is not Premium.
// App Store build only.
#if APP_STORE
import SwiftUI

struct PaywallView: View {
    @State private var store = StoreManager.shared
    private let trial = TrialState.shared
    private let loc = LocalizationManager.shared
    private let accent = Color(hex: "#2D6A4F")

    var body: some View {
        ZStack {
            // Solid background — covers the dashboard underneath
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 0)

                // Icon (uses the bundled AppIcon)
                if let nsImage = NSImage(named: "AppIcon") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(radius: 8, y: 4)
                }

                VStack(spacing: 10) {
                    Text(loc.t("paywall.title"))
                        .font(.system(size: 26, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Text(loc.t("paywall.subtitle"))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    featureRow("clock.fill", loc.t("paywall.feature.timer"))
                    featureRow("chart.bar.fill", loc.t("paywall.feature.stats"))
                    featureRow("target", loc.t("paywall.feature.goals"))
                    featureRow("lock.shield.fill", loc.t("paywall.feature.offline"))
                }
                .padding(.horizontal, 8)

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Button(action: { Task { await store.buy() } }) {
                        Text(buyButtonLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(accent)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.product == nil || store.purchaseState == .purchasing)

                    Button(action: { Task { await store.restore() } }) {
                        Text(loc.t("paywall.cta_restore"))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if case .failed(let msg) = store.purchaseState {
                    Text(msg.isEmpty ? loc.t("paywall.error.generic") : msg)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 36)
            .frame(maxWidth: 480)
        }
        .task {
            if store.product == nil {
                await store.loadProducts()
            }
        }
        .id(trial.isPremium) // refresh subtree when premium flips → naturally dismisses
    }

    private var buyButtonLabel: String {
        if store.purchaseState == .purchasing {
            return loc.t("paywall.cta_buy_loading")
        }
        if let price = store.displayPrice {
            return String(format: loc.t("paywall.cta_buy"), price)
        }
        return loc.t("paywall.cta_buy_loading")
    }

    @ViewBuilder
    private func featureRow(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(accent)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 13))
            Spacer()
        }
    }
}
#endif
