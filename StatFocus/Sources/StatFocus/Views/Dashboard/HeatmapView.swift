// StatFocus/Views/Dashboard/HeatmapView.swift
import SwiftUI

struct HeatmapView: View {
    let data: [(date: Date, hours: Double)]
    let maxHours: Double
    let accent = Color(hex: "#2D6A4F")

    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 2
    private let weeksPerYear = 53  // safe upper bound

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Atividade do Ano")
                .font(.headline)

            // Month labels row
            monthLabelsRow()

            // The heatmap grid: columns = weeks, rows = days of week
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.fixed(cellSize), spacing: cellSpacing),
                    count: weeksPerYear
                ),
                spacing: cellSpacing
            ) {
                ForEach(paddedData(), id: \.index) { entry in
                    if let item = entry.item {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(cellColor(hours: item.hours))
                            .frame(width: cellSize, height: cellSize)
                            .help(tooltip(for: item))
                    } else {
                        Color.clear
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }

            // Legend
            HStack(spacing: 4) {
                Text("Menos")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(level == 0 ? Color.gray.opacity(0.15) : accent.opacity(0.2 + level * 0.8))
                        .frame(width: cellSize, height: cellSize)
                }
                Text("Mais")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func cellColor(hours: Double) -> Color {
        guard hours > 0, maxHours > 0 else { return Color.gray.opacity(0.12) }
        let rawIntensity = min(hours / maxHours, 1.0)
        // Quantize to 4 levels (like GitHub)
        let level = (ceil(rawIntensity * 4) / 4)
        return accent.opacity(0.2 + level * 0.8)
    }

    private func tooltip(for item: (date: Date, hours: Double)) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: item.date)
        if item.hours < 0.01 {
            return "\(dateStr): sem estudo"
        }
        return "\(dateStr): \(String(format: "%.1f", item.hours))h"
    }

    /// Struct to hold padded grid entries with stable index
    private struct GridEntry: Identifiable {
        let id = UUID()
        let index: Int
        let item: (date: Date, hours: Double)?
    }

    /// Pads data array so the first entry falls in the correct weekday row (Sun=0)
    private func paddedData() -> [GridEntry] {
        guard let first = data.first else { return [] }
        let cal = Calendar.autoupdatingCurrent
        // weekday: 1=Sun ... 7=Sat → we want 0-indexed offset
        let firstWeekdayOffset = (cal.component(.weekday, from: first.date) - 1)

        var entries: [GridEntry] = []
        var idx = 0

        // Leading empty cells
        for _ in 0..<firstWeekdayOffset {
            entries.append(GridEntry(index: idx, item: nil))
            idx += 1
        }

        // Real data
        for item in data {
            entries.append(GridEntry(index: idx, item: item))
            idx += 1
        }

        // Trailing empty cells to complete the last column (7 rows each)
        let remainder = entries.count % 7
        if remainder != 0 {
            for _ in 0..<(7 - remainder) {
                entries.append(GridEntry(index: idx, item: nil))
                idx += 1
            }
        }

        return entries
    }

    @ViewBuilder
    private func monthLabelsRow() -> some View {
        let labels = monthLabelPositions()
        ZStack(alignment: .topLeading) {
            ForEach(labels, id: \.label) { entry in
                Text(entry.label)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .offset(x: CGFloat(entry.column) * (cellSize + cellSpacing))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 12)
    }

    private func monthLabelPositions() -> [(label: String, column: Int)] {
        guard !data.isEmpty else { return [] }
        let cal = Calendar.autoupdatingCurrent
        let firstWeekdayOffset = cal.component(.weekday, from: data[0].date) - 1
        var result: [(label: String, column: Int)] = []
        var lastMonth = -1

        for (dayIdx, item) in data.enumerated() {
            let month = cal.component(.month, from: item.date)
            if month != lastMonth {
                let col = (dayIdx + firstWeekdayOffset) / 7
                let label = cal.shortMonthSymbols[month - 1]
                result.append((label: label, column: col))
                lastMonth = month
            }
        }
        return result
    }
}
