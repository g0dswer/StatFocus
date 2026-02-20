// StatFocus/ViewModels/TimerViewModel.swift
import Foundation
import AppKit
import Observation

enum TimerState {
    case idle
    case running
    case paused
}

enum PomodoroPhase {
    case focus
    case shortBreak
    case longBreak
}

@Observable
class TimerViewModel {
    // State
    var timerState: TimerState = .idle
    var phase: PomodoroPhase = .focus
    var secondsRemaining: Int = 0
    var completedCycles: Int = 0

    let settings = AppSettings.shared

    private var timer: Timer?
    private var sessionStart: Date?
    private let store: SessionStore

    init(store: SessionStore = .shared) {
        self.store = store
        resetToCurrentPhase()
    }

    // MARK: - Computed

    var totalSeconds: Int {
        switch phase {
        case .focus:      return settings.focusDuration * 60
        case .shortBreak: return settings.shortBreakDuration * 60
        case .longBreak:  return settings.longBreakDuration * 60
        }
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - secondsRemaining) / Double(totalSeconds)
    }

    var timeString: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    var cycleCount: Int { settings.cyclesBeforeLongBreak }

    // MARK: - Actions

    func play() {
        guard timerState != .running else { return }
        if timerState == .idle {
            sessionStart = Date()
        }
        timerState = .running
        scheduleTimer()
    }

    func pause() {
        guard timerState == .running else { return }
        timerState = .paused
        timer?.invalidate()
    }

    func stop() {
        timer?.invalidate()
        if let start = sessionStart {
            let elapsed = Date().timeIntervalSince(start)
            if elapsed >= 60 {
                saveSession(startedAt: start, duration: elapsed, type: sessionTypeForPhase())
            }
        }
        timerState = .idle
        sessionStart = nil
        resetToCurrentPhase()
    }

    // MARK: - Private

    private func scheduleTimer() {
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard secondsRemaining > 0 else {
            completePhase()
            return
        }
        secondsRemaining -= 1
    }

    private func completePhase() {
        timer?.invalidate()
        if let start = sessionStart {
            let elapsed = Date().timeIntervalSince(start)
            saveSession(startedAt: start, duration: elapsed, type: sessionTypeForPhase())
        }
        playCompletionSound()
        advancePhase()
        sessionStart = Date()
        scheduleTimer()
    }

    private func advancePhase() {
        switch phase {
        case .focus:
            completedCycles += 1
            if completedCycles >= settings.cyclesBeforeLongBreak {
                completedCycles = 0
                phase = .longBreak
            } else {
                phase = .shortBreak
            }
        case .shortBreak, .longBreak:
            phase = .focus
        }
        resetToCurrentPhase()
    }

    private func resetToCurrentPhase() {
        secondsRemaining = totalSeconds
    }

    private func sessionTypeForPhase() -> SessionType {
        switch phase {
        case .focus:      return .focus
        case .shortBreak: return .shortBreak
        case .longBreak:  return .longBreak
        }
    }

    private func saveSession(startedAt: Date, duration: TimeInterval, type: SessionType) {
        let session = StudySession(startedAt: startedAt, duration: duration, type: type)
        store.insert(session)
        // Notify stats view model to refresh
        NotificationCenter.default.post(name: .sessionsUpdated, object: nil)
    }

    private func playCompletionSound() {
        guard settings.soundEnabled else { return }
        NSSound(named: "Glass")?.play()
    }

    // MARK: - Debug

    #if DEBUG
    func seedTestData() {
        var sessions: [StudySession] = store.loadAll()
        for dayOffset in 0..<60 {
            if dayOffset % 7 == 3 { continue }
            let date = Date().adding(days: -dayOffset)
            let count = Int.random(in: 2...6)
            for _ in 0..<count {
                sessions.append(StudySession(
                    startedAt: date,
                    duration: Double.random(in: 1200...3000),
                    type: .focus
                ))
            }
        }
        store.save(sessions)
        NotificationCenter.default.post(name: .sessionsUpdated, object: nil)
    }
    #endif
}

extension Notification.Name {
    static let sessionsUpdated = Notification.Name("com.statfocus.sessionsUpdated")
}
