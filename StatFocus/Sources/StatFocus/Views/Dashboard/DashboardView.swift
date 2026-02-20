// StatFocus/Views/Dashboard/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @Bindable var statsViewModel: StatsViewModel
    @State private var selectedTab: Tab = .stats

    enum Tab: String, CaseIterable {
        case stats = "Estatísticas"
        case settings = "Configurações"

        var icon: String {
            switch self {
            case .stats: return "chart.bar.fill"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            StatsView(viewModel: statsViewModel)
                .tabItem {
                    Label("Estatísticas", systemImage: "chart.bar.fill")
                }
                .tag(Tab.stats)

            SettingsView()
                .tabItem {
                    Label("Configurações", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
        .frame(minWidth: 720, minHeight: 520)
    }
}
