// StatFocus/Models/AppSettings.swift
import Foundation
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var focusDuration: Int {
        didSet { UserDefaults.standard.set(focusDuration, forKey: "focusDuration") }
    }
    @Published var shortBreakDuration: Int {
        didSet { UserDefaults.standard.set(shortBreakDuration, forKey: "shortBreakDuration") }
    }
    @Published var longBreakDuration: Int {
        didSet { UserDefaults.standard.set(longBreakDuration, forKey: "longBreakDuration") }
    }
    @Published var cyclesBeforeLongBreak: Int {
        didSet { UserDefaults.standard.set(cyclesBeforeLongBreak, forKey: "cyclesBeforeLongBreak") }
    }
    @Published var dailyGoalHours: Double {
        didSet { UserDefaults.standard.set(dailyGoalHours, forKey: "dailyGoalHours") }
    }
    @Published var weeklyGoalHours: Double {
        didSet { UserDefaults.standard.set(weeklyGoalHours, forKey: "weeklyGoalHours") }
    }
    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }

    private init() {
        let ud = UserDefaults.standard
        focusDuration = ud.integer(forKey: "focusDuration").nonZero ?? 25
        shortBreakDuration = ud.integer(forKey: "shortBreakDuration").nonZero ?? 5
        longBreakDuration = ud.integer(forKey: "longBreakDuration").nonZero ?? 15
        cyclesBeforeLongBreak = ud.integer(forKey: "cyclesBeforeLongBreak").nonZero ?? 4
        dailyGoalHours = ud.double(forKey: "dailyGoalHours").nonZero ?? 4.0
        weeklyGoalHours = ud.double(forKey: "weeklyGoalHours").nonZero ?? 20.0
        soundEnabled = ud.object(forKey: "soundEnabled") as? Bool ?? true
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
