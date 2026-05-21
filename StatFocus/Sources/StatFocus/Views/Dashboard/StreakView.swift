// StatFocus/Views/Dashboard/StreakView.swift
import SwiftUI

struct StreakView: View {
    let current: Int
    let best: Int
    let accent = Color(hex: "#2D6A4F")
    private let loc = LocalizationManager.shared

    var body: some View {
        HStack(spacing: 0) {
            // Current streak
            VStack(spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("🔥")
                        .font(.title2)
                    Text("\(current)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(current > 0 ? accent : .secondary)
                        .contentTransition(.numericText())
                }
                Text(loc.t(current == 1 ? "stats.streak.day_one" : "stats.streak.day_many"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 56)

            // Best streak record
            VStack(spacing: 4) {
                Text("\(best)")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .contentTransition(.numericText())
                Text(loc.t("stats.streak.record"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
