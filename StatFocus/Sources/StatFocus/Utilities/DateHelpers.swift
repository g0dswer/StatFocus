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
