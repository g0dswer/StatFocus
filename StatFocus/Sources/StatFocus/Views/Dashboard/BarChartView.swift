// StatFocus/Views/Dashboard/BarChartView.swift
import SwiftUI

struct BarChartView: View {
    let data: [(label: String, hours: Double)]
    let accent = Color(hex: "#2D6A4F")

    private let maxBarHeight: CGFloat = 120
    private let barWidth: CGFloat = 28

    private var maxHours: Double {
        max(data.map(\.hours).max() ?? 0, 0.001)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(data.indices, id: \.self) { i in
                barColumn(item: data[i], isLast: i == data.indices.last)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func barColumn(item: (label: String, hours: Double), isLast: Bool) -> some View {
        let barHeight = max(4, CGFloat(item.hours / maxHours) * maxBarHeight)
        let isToday = isLast  // last entry is most recent

        VStack(spacing: 4) {
            // Value label above bar
            if item.hours > 0 {
                Text(formatHours(item.hours))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(height: 12)
            } else {
                Spacer().frame(height: 12)
            }

            // The bar
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    isToday
                        ? accent
                        : accent.opacity(item.hours > 0 ? 0.6 : 0.1)
                )
                .frame(width: barWidth, height: barHeight)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: barHeight)

            // Day label
            Text(item.label)
                .font(.system(size: 9))
                .foregroundColor(isToday ? accent : .secondary)
                .fontWeight(isToday ? .semibold : .regular)
        }
    }

    private func formatHours(_ h: Double) -> String {
        if h < 1 {
            return "\(Int(h * 60))m"
        }
        return String(format: "%.1fh", h)
    }
}
