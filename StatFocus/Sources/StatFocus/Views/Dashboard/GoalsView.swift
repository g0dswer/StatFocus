// StatFocus/Views/Dashboard/GoalsView.swift
import SwiftUI

struct GoalsView: View {
    let todayHours: Double
    let dailyGoal: Double
    let weekHours: Double
    let weeklyGoal: Double

    var dailyProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(todayHours / dailyGoal, 1.0)
    }

    var weeklyProgress: Double {
        guard weeklyGoal > 0 else { return 0 }
        return min(weekHours / weeklyGoal, 1.0)
    }

    var body: some View {
        HStack(spacing: 40) {
            CircularProgressView(
                progress: dailyProgress,
                label: "hoje",
                sublabel: "\(formatHours(todayHours)) / \(formatHours(dailyGoal))"
            )

            CircularProgressView(
                progress: weeklyProgress,
                label: "semana",
                sublabel: "\(formatHours(weekHours)) / \(formatHours(weeklyGoal))"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatHours(_ h: Double) -> String {
        let totalMinutes = Int(h * 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }
}
