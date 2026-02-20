// StatFocus/Views/Dashboard/StatsView.swift
import SwiftUI

struct StatsView: View {
    @Bindable var viewModel: StatsViewModel
    @State private var chartPeriod: StatsViewModel.ChartPeriod = .day

    private var heatmapData: [(date: Date, hours: Double)] {
        viewModel.heatmapData()
    }

    private var maxHoursInHeatmap: Double {
        heatmapData.map(\.hours).max() ?? 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // — Streak ——————————————————————
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sequência")
                        .font(.headline)
                    StreakView(
                        current: viewModel.currentStreak,
                        best: viewModel.bestStreak
                    )
                }

                // — Metas ——————————————————————
                VStack(alignment: .leading, spacing: 12) {
                    Text("Metas")
                        .font(.headline)
                    GoalsView(
                        todayHours: viewModel.todayFocusHours,
                        dailyGoal: AppSettings.shared.dailyGoalHours,
                        weekHours: viewModel.weekFocusHours,
                        weeklyGoal: AppSettings.shared.weeklyGoalHours
                    )
                }

                // — Heatmap ——————————————————————
                HeatmapView(
                    data: heatmapData,
                    maxHours: maxHoursInHeatmap
                )

                // — Bar Chart ——————————————————————
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Horas de Foco")
                            .font(.headline)
                        Spacer()
                        Picker("", selection: $chartPeriod) {
                            ForEach(StatsViewModel.ChartPeriod.allCases, id: \.self) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 260)
                    }

                    BarChartView(data: viewModel.barChartData(period: chartPeriod))
                        .frame(height: 160)
                }
            }
            .padding(28)
        }
        .onAppear {
            viewModel.loadSessions()
        }
    }
}
