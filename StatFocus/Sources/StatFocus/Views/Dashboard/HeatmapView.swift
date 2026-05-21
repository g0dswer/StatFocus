// StatFocus/Views/Dashboard/HeatmapView.swift
import SwiftUI

struct HeatmapView: View {
    let data: [(date: Date, hours: Double)]
    let accent = Color(hex: "#2D6A4F")
    @State private var hoveredItem: (date: Date, hours: Double)?
    private let loc = LocalizationManager.shared

    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 2
    private let weeksPerYear = 53  // safe upper bound
    private var heatmapWidth: CGFloat {
        CGFloat(weeksPerYear) * cellSize + CGFloat(weeksPerYear - 1) * cellSpacing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(loc.t("stats.year_activity"))
                .font(.headline)

            // The heatmap grid: columns = weeks, rows = days of week
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    monthLabelsRow()
                        .frame(width: heatmapWidth, alignment: .leading)

                    LazyHGrid(
                        rows: Array(
                            repeating: GridItem(.fixed(cellSize), spacing: cellSpacing),
                            count: 7
                        ),
                        spacing: cellSpacing
                    ) {
                        ForEach(paddedData(), id: \.index) { entry in
                            if let item = entry.item {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(cellColor(hours: item.hours))
                                    .frame(width: cellSize, height: cellSize)
                                    .onHover { isHovered in
                                        if isHovered {
                                            hoveredItem = item
                                        } else if hoveredItem?.date == item.date {
                                            hoveredItem = nil
                                        }
                                    }
                                    .help(tooltip(for: item))
                            } else {
                                Color.clear
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                    .frame(height: cellSize * 7 + cellSpacing * 6)
                }
            }

            // Fixed legend: 0, <1h, 1-2h, 2-4h, 4h+
            HStack(spacing: 4) {
                ForEach(0...4, id: \.self) { level in
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(for: level))
                            .frame(width: cellSize, height: cellSize)
                        Text(legendLabel(for: level))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let hoveredItem {
                Text(tooltip(for: hoveredItem))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Helpers

    private func cellColor(hours: Double) -> Color {
        color(for: intensityLevel(hours: hours))
    }

    private func intensityLevel(hours: Double) -> Int {
        if hours <= 0 { return 0 }
        if hours < 1  { return 1 }
        if hours < 2  { return 2 }
        if hours < 4  { return 3 }
        return 4
    }

    private func legendLabel(for level: Int) -> String {
        switch level {
        case 0: return "0h"
        case 1: return "<1h"
        case 2: return "1-2h"
        case 3: return "2-4h"
        case 4: return "4h+"
        default: return ""
        }
    }

    private func color(for level: Int) -> Color {
        switch level {
        case 1: return accent.opacity(0.28)
        case 2: return accent.opacity(0.46)
        case 3: return accent.opacity(0.68)
        case 4: return accent.opacity(0.9)
        default: return Color.gray.opacity(0.12)
        }
    }

    private func tooltip(for item: (date: Date, hours: Double)) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: item.date)
        if item.hours < 0.01 {
            return "\(dateStr): \(loc.t("stats.no_study"))"
        }
        return "\(dateStr): \(String(format: "%.1f", item.hours))h"
    }

    /// Struct to hold padded grid entries with stable index
    private struct GridEntry {
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
            ForEach(Array(labels.enumerated()), id: \.offset) { _, entry in
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
