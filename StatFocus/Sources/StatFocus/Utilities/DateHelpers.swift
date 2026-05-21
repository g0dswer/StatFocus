// StatFocus/Utilities/DateHelpers.swift
import Foundation

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: comps) ?? date
    }

    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}

extension Date {
    var dayStart: Date { Calendar.autoupdatingCurrent.startOfDay(for: self) }

    func adding(days: Int) -> Date {
        Calendar.autoupdatingCurrent.date(byAdding: .day, value: days, to: self) ?? self
    }
}

enum HeatmapIntensity {
    // Fixed scale:
    // 0 = no study, 1 = (0,1), 2 = [1,2), 3 = [2,4), 4 = >= 4 hours
    static func level(hours: Double) -> Int {
        guard hours > 0 else { return 0 }
        if hours < 1 { return 1 }
        if hours < 2 { return 2 }
        if hours < 4 { return 3 }
        return 4
    }
}
