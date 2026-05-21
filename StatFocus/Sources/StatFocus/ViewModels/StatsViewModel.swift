// StatFocus/ViewModels/StatsViewModel.swift
import Foundation
import Observation

@Observable
class StatsViewModel {
    var sessions: [StudySession] = []
    private let store: SessionStore

    init(store: SessionStore = .shared) {
        self.store = store
        loadSessions()
        // Refresh whenever timer saves a new session
        NotificationCenter.default.addObserver(
            forName: .sessionsUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadSessions()
        }
    }

    func loadSessions() {
        sessions = store.loadAll()
            .sorted { $0.startedAt < $1.startedAt }
    }

    // MARK: - Heatmap

    func heatmapData() -> [(date: Date, hours: Double)] {
        let cal = Calendar.autoupdatingCurrent
        let year = cal.component(.year, from: Date())
        let startDate = cal.date(from: DateComponents(year: year, month: 1, day: 1))!
        let endDate   = cal.date(from: DateComponents(year: year, month: 12, day: 31))!
        var result: [(date: Date, hours: Double)] = []
        var current = startDate
        while current <= endDate {
            result.append((date: current, hours: focusHours(for: current)))
            current = current.adding(days: 1)
        }
        return result
    }

    func focusHours(for day: Date) -> Double {
        let cal = Calendar.autoupdatingCurrent
        let secs = sessions
            .filter { $0.type == .focus && cal.isDate($0.startedAt, inSameDayAs: day) }
            .reduce(0.0) { $0 + $1.duration }
        return secs / 3600
    }

    // MARK: - Streak

    var currentStreak: Int {
        let today = Date().dayStart
        var streak = 0
        var day = today
        while focusHours(for: day) > 0 {
            streak += 1
            day = day.adding(days: -1)
            if streak > 10_000 { break }
        }
        return streak
    }

    var bestStreak: Int {
        guard !sessions.isEmpty else { return 0 }
        let cal = Calendar.autoupdatingCurrent
        let allDays = Set(
            sessions
                .filter { $0.type == .focus }
                .map { cal.startOfDay(for: $0.startedAt) }
        ).sorted()

        var best = 0, current = 0
        var prev: Date? = nil
        for day in allDays {
            if let p = prev,
               cal.dateComponents([.day], from: p, to: day).day == 1 {
                current += 1
            } else {
                current = 1
            }
            best = max(best, current)
            prev = day
        }
        return best
    }

    // MARK: - Goals

    var todayFocusHours: Double { focusHours(for: Date().dayStart) }

    var weekFocusHours: Double {
        let start = Calendar.autoupdatingCurrent.startOfWeek(for: Date())
        return sessions
            .filter { $0.type == .focus && $0.startedAt >= start }
            .reduce(0.0) { $0 + $1.duration } / 3600
    }

    // MARK: - Hourly Focus Distribution

    enum HourlyPeriod: String, CaseIterable {
        case last7  = "7d"
        case last30 = "30d"
        case all    = "all"

        var titleKey: String {
            switch self {
            case .last7:  return "hourly.7d"
            case .last30: return "hourly.30d"
            case .all:    return "hourly.all"
            }
        }
    }

    /// Returns 24 buckets (one per hour-of-day) with focused hours.
    /// Sessions that cross hour boundaries are distributed proportionally.
    /// `period` filters by `startedAt` cutoff (e.g. last 7 days).
    func hourlyFocusData(
        period: HourlyPeriod = .all,
        now: Date = Date()
    ) -> [(hour: Int, hours: Double)] {
        let cal = Calendar.autoupdatingCurrent
        var seconds = Array(repeating: 0.0, count: 24)

        let cutoff = cutoffDate(for: period, now: now, calendar: cal)
        for session in sessions where session.type == .focus {
            if let cutoff, session.startedAt < cutoff { continue }
            distribute(session: session, calendar: cal, into: &seconds)
        }

        return (0..<24).map { (hour: $0, hours: seconds[$0] / 3600) }
    }

    private func cutoffDate(for period: HourlyPeriod, now: Date, calendar: Calendar) -> Date? {
        switch period {
        case .all:    return nil
        case .last7:  return calendar.startOfDay(for: now).adding(days: -6)
        case .last30: return calendar.startOfDay(for: now).adding(days: -29)
        }
    }

    private func distribute(
        session: StudySession,
        calendar: Calendar,
        into seconds: inout [Double]
    ) {
        let end = session.startedAt.addingTimeInterval(session.duration)
        var cursor = session.startedAt
        while cursor < end {
            let hour = calendar.component(.hour, from: cursor)
            let hourStart = calendar.date(
                bySettingHour: hour, minute: 0, second: 0, of: cursor
            ) ?? cursor
            let nextHourStart = calendar.date(
                byAdding: .hour, value: 1, to: hourStart
            ) ?? end
            let segmentEnd = min(nextHourStart, end)
            seconds[hour] += segmentEnd.timeIntervalSince(cursor)
            cursor = segmentEnd
        }
    }

    // MARK: - Bar Chart

    enum ChartPeriod: String, CaseIterable {
        case day
        case week
        case month
        case year

        var titleKey: String {
            switch self {
            case .day:   return "period.day"
            case .week:  return "period.week"
            case .month: return "period.month"
            case .year:  return "period.year"
            }
        }
    }

    func barChartData(period: ChartPeriod) -> [(label: String, hours: Double)] {
        let cal = Calendar.autoupdatingCurrent

        switch period {
        case .day:
            return (0..<7).reversed().map { offset -> (label: String, hours: Double) in
                let day = Date().dayStart.adding(days: -offset)
                let label = cal.shortWeekdaySymbols[cal.component(.weekday, from: day) - 1]
                return (label: label, hours: focusHours(for: day))
            }

        case .week:
            let thisWeek = cal.startOfWeek(for: Date())
            return (0..<8).reversed().map { offset -> (label: String, hours: Double) in
                let weekStart = cal.date(byAdding: .weekOfYear, value: -offset, to: thisWeek)!
                let weekEnd   = weekStart.adding(days: 7)
                let hours = sessions
                    .filter { $0.type == .focus && $0.startedAt >= weekStart && $0.startedAt < weekEnd }
                    .reduce(0.0) { $0 + $1.duration } / 3600
                return (label: "S\(cal.component(.weekOfYear, from: weekStart))", hours: hours)
            }

        case .month:
            let thisMonth = cal.startOfMonth(for: Date())
            return (0..<12).reversed().map { offset -> (label: String, hours: Double) in
                let mStart = cal.date(byAdding: .month, value: -offset, to: thisMonth)!
                let mEnd   = cal.date(byAdding: .month, value: 1, to: mStart)!
                let hours = sessions
                    .filter { $0.type == .focus && $0.startedAt >= mStart && $0.startedAt < mEnd }
                    .reduce(0.0) { $0 + $1.duration } / 3600
                return (label: cal.shortMonthSymbols[cal.component(.month, from: mStart) - 1], hours: hours)
            }

        case .year:
            let currentYear = cal.component(.year, from: Date())
            return (0..<5).reversed().map { offset -> (label: String, hours: Double) in
                let year      = currentYear - offset
                let yearStart = cal.date(from: DateComponents(year: year))!
                let yearEnd   = cal.date(byAdding: .year, value: 1, to: yearStart)!
                let hours = sessions
                    .filter { $0.type == .focus && $0.startedAt >= yearStart && $0.startedAt < yearEnd }
                    .reduce(0.0) { $0 + $1.duration } / 3600
                return (label: "\(year)", hours: hours)
            }
        }
    }
}
