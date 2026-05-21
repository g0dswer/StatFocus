// StatFocus/Views/Dashboard/StatsView.swift
import SwiftUI

struct StatsView: View {
    @Bindable var viewModel: StatsViewModel
    @State private var chartPeriod: StatsViewModel.ChartPeriod = .day
    @State private var hourlyPeriod: StatsViewModel.HourlyPeriod = .all
    private let loc = LocalizationManager.shared

    private var heatmapData: [(date: Date, hours: Double)] {
        viewModel.heatmapData()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // — Streak ——————————————————————
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.t("stats.streak"))
                        .font(.headline)
                    StreakView(
                        current: viewModel.currentStreak,
                        best: viewModel.bestStreak
                    )
                }

                // — Metas ——————————————————————
                VStack(alignment: .leading, spacing: 12) {
                    Text(loc.t("stats.goals"))
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
                    data: heatmapData
                )

                // — Hourly Focus ————————————————————
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(loc.t("stats.hourly_title"))
                            .font(.headline)
                        Spacer()
                        Picker("", selection: $hourlyPeriod) {
                            ForEach(StatsViewModel.HourlyPeriod.allCases, id: \.self) { p in
                                Text(loc.t(p.titleKey)).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }

                    HourlyHeatmapView(data: viewModel.hourlyFocusData(period: hourlyPeriod))
                }

                // — Bar Chart ——————————————————————
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(loc.t("stats.hours_title"))
                            .font(.headline)
                        Spacer()
                        Picker("", selection: $chartPeriod) {
                            ForEach(StatsViewModel.ChartPeriod.allCases, id: \.self) { p in
                                Text(loc.t(p.titleKey)).tag(p)
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
