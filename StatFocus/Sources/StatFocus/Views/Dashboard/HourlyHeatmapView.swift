// StatFocus/Views/Dashboard/HourlyHeatmapView.swift
import SwiftUI

struct HourlyHeatmapView: View {
    let data: [(hour: Int, hours: Double)]
    private let accent = Color(hex: "#2D6A4F")
    private let cellHeight: CGFloat = 36
    private let cellSpacing: CGFloat = 3
    @State private var hoveredHour: Int?
    private let loc = LocalizationManager.shared

    private var maxHours: Double {
        max(data.map(\.hours).max() ?? 0, 0.001)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: cellSpacing) {
                ForEach(data, id: \.hour) { item in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(cellColor(for: item.hours))
                            .frame(height: cellHeight)
                            .onHover { isHovered in
                                if isHovered {
                                    hoveredHour = item.hour
                                } else if hoveredHour == item.hour {
                                    hoveredHour = nil
                                }
                            }
                            .help(tooltip(for: item))

                        Text(item.hour % 3 == 0 ? "\(item.hour)h" : " ")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 4) {
                Text(loc.t("stats.legend.less"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                ForEach(0...4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: level))
                        .frame(width: 12, height: 12)
                }
                Text(loc.t("stats.legend.more"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let hoveredHour, let item = data.first(where: { $0.hour == hoveredHour }) {
                Text(tooltip(for: item))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Helpers

    private func cellColor(for hours: Double) -> Color {
        color(for: intensityLevel(for: hours))
    }

    private func intensityLevel(for hours: Double) -> Int {
        guard hours > 0 else { return 0 }
        let ratio = hours / maxHours
        if ratio <= 0.25 { return 1 }
        if ratio <= 0.50 { return 2 }
        if ratio <= 0.75 { return 3 }
        return 4
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

    private func tooltip(for item: (hour: Int, hours: Double)) -> String {
        let next = (item.hour + 1) % 24
        let range = String(format: "%02d:00–%02d:00", item.hour, next)
        if item.hours < 0.0167 { // less than 1 minute
            return "\(range): \(loc.t("stats.no_focus"))"
        }
        let totalMinutes = Int((item.hours * 60).rounded())
        if totalMinutes < 60 {
            return "\(range): \(totalMinutes)min"
        }
        return "\(range): \(String(format: "%.1f", item.hours))h"
    }
}
