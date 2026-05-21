// StatFocus/Views/Dashboard/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @Bindable var statsViewModel: StatsViewModel
    @State private var selectedTab: Tab = .stats
    private let loc = LocalizationManager.shared
    #if APP_STORE
    @State private var trial = TrialState.shared
    @State private var showingPaywall = false
    #endif

    enum Tab: String, CaseIterable, Identifiable {
        case stats
        case settings

        var id: String { rawValue }
        var titleKey: String {
            switch self {
            case .stats: return "tab.stats"
            case .settings: return "tab.settings"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            #if APP_STORE
            // Trial countdown banner shown only while in trial.
            if trial.isInTrial {
                TrialBanner(trial: trial, onBuy: { showingPaywall = true })
            }
            #endif

            // Custom top bar: centered tab picker + trailing language toggle.
            ZStack {
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(loc.t(tab.titleKey)).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)

                HStack {
                    Spacer()
                    LanguageToggleButton()
                        .padding(.trailing, 14)
                }
            }
            .padding(.vertical, 10)

            Divider()

            Group {
                switch selectedTab {
                case .stats:
                    StatsView(viewModel: statsViewModel)
                case .settings:
                    SettingsView()
                }
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        #if APP_STORE
        .overlay {
            // Hard paywall: covers everything when the trial expired.
            if trial.isLocked {
                PaywallView()
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
                .frame(minWidth: 480, minHeight: 600)
        }
        #endif
    }
}
