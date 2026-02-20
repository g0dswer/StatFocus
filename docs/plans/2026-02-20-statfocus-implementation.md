# StatFocus Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS native Pomodoro timer app (Swift + SwiftUI) with rich study statistics — floating always-on-top timer window, heatmap, streak counter, and daily/weekly goals.

**Architecture:** NSPanel floating window for the timer (always-on-top, no Dock icon). SwiftData for local session persistence. Separate Dashboard window for statistics and settings. AppDelegate-based app lifecycle (not SwiftUI @main) to control window behavior precisely.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, AppKit (NSPanel, NSWindow), ServiceManagement (launch at login), UserNotifications, macOS 14+

---

## Project Structure

```
StatFocus/
├── StatFocus.xcodeproj
└── StatFocus/
    ├── App/
    │   ├── StatFocusApp.swift          # @main, AppDelegate
    │   └── AppDelegate.swift           # Window management
    ├── Models/
    │   ├── StudySession.swift          # SwiftData model
    │   └── AppSettings.swift           # UserDefaults-backed settings
    ├── ViewModels/
    │   ├── TimerViewModel.swift        # Timer logic, state machine
    │   └── StatsViewModel.swift        # Statistics computations
    ├── Views/
    │   ├── Timer/
    │   │   ├── TimerView.swift         # Main floating window content
    │   │   ├── CycleDotsView.swift     # ● ● ● ● indicators
    │   │   └── TimerControlsView.swift # Play/Pause/Stop buttons
    │   ├── Dashboard/
    │   │   ├── DashboardView.swift     # Tab container
    │   │   ├── StatsView.swift         # Statistics tab
    │   │   ├── HeatmapView.swift       # GitHub-style annual heatmap
    │   │   ├── StreakView.swift        # Streak + record display
    │   │   ├── GoalsView.swift         # Daily/weekly progress
    │   │   ├── BarChartView.swift      # D/S/M/A bar chart
    │   │   └── SettingsView.swift      # Settings tab
    │   └── Components/
    │       ├── CircularProgressView.swift
    │       └── LinearProgressView.swift
    └── Utilities/
        └── DateHelpers.swift           # Calendar utilities
```

---

## Task 1: Xcode Project Setup

**Files:**
- Create: `StatFocus.xcodeproj` (via Xcode)
- Create: `StatFocus/App/StatFocusApp.swift`
- Create: `StatFocus/App/AppDelegate.swift`

**Step 1: Create the Xcode project**

Open Xcode → New Project → macOS → App
- Product Name: `StatFocus`
- Bundle ID: `com.yourname.statfocus`
- Interface: SwiftUI
- Language: Swift
- Uncheck: "Include Tests" (add later manually)
- Deployment Target: macOS 14.0

**Step 2: Replace `StatFocusApp.swift` with AppDelegate-based entry point**

```swift
// StatFocus/App/StatFocusApp.swift
import SwiftUI

@main
struct StatFocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty — windows are managed by AppDelegate
        Settings { EmptyView() }
    }
}
```

**Step 3: Create `AppDelegate.swift`**

```swift
// StatFocus/App/AppDelegate.swift
import AppKit
import SwiftUI
import SwiftData

class AppDelegate: NSObject, NSApplicationDelegate {
    var timerPanel: NSPanel?
    var dashboardWindow: NSWindow?

    let modelContainer: ModelContainer = {
        let schema = Schema([StudySession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: config)
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon — accessory app
        NSApp.setActivationPolicy(.accessory)
        setupTimerPanel()
    }

    func setupTimerPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 220),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = ""
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .windowBackgroundColor
        panel.isOpaque = false
        panel.hasShadow = true
        panel.center()

        let timerVM = TimerViewModel(modelContext: modelContainer.mainContext)
        let contentView = TimerView(viewModel: timerVM, onOpenDashboard: { [weak self] in
            self?.openDashboard()
        })
        panel.contentView = NSHostingView(rootView: contentView)
        panel.makeKeyAndOrderFront(nil)
        self.timerPanel = panel
    }

    func openDashboard() {
        if let existing = dashboardWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "StatFocus"
        window.center()
        window.delegate = self
        let statsVM = StatsViewModel(modelContext: modelContainer.mainContext)
        let dashView = DashboardView(statsViewModel: statsVM)
            .modelContainer(modelContainer)
        window.contentView = NSHostingView(rootView: dashView)
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        self.dashboardWindow = window
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === dashboardWindow {
            dashboardWindow = nil
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
```

**Step 4: Verify the project compiles (empty views OK for now)**

Build with Cmd+B. Fix any import errors.

**Step 5: Commit**

```bash
git init
git add .
git commit -m "feat: initial Xcode project with AppDelegate window management"
```

---

## Task 2: Data Models

**Files:**
- Create: `StatFocus/Models/StudySession.swift`
- Create: `StatFocus/Models/AppSettings.swift`

**Step 1: Create `StudySession.swift`**

```swift
// StatFocus/Models/StudySession.swift
import Foundation
import SwiftData

enum SessionType: String, Codable {
    case focus
    case shortBreak
    case longBreak
}

@Model
final class StudySession {
    var id: UUID
    var startedAt: Date
    var duration: TimeInterval  // seconds of actual elapsed time
    var type: SessionType

    init(startedAt: Date, duration: TimeInterval, type: SessionType) {
        self.id = UUID()
        self.startedAt = startedAt
        self.duration = duration
        self.type = type
    }
}
```

**Step 2: Create `AppSettings.swift`**

```swift
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
```

**Step 3: Build to verify — Cmd+B**

**Step 4: Commit**

```bash
git add StatFocus/Models/
git commit -m "feat: SwiftData StudySession model and AppSettings"
```

---

## Task 3: Timer State Machine (ViewModel)

**Files:**
- Create: `StatFocus/ViewModels/TimerViewModel.swift`

**Step 1: Create `TimerViewModel.swift`**

```swift
// StatFocus/ViewModels/TimerViewModel.swift
import Foundation
import SwiftData
import AppKit

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

    // Settings ref
    let settings = AppSettings.shared

    private var timer: Timer?
    private var sessionStart: Date?
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        resetToCurrentPhase()
    }

    // MARK: - Computed

    var totalSeconds: Int {
        switch phase {
        case .focus: return settings.focusDuration * 60
        case .shortBreak: return settings.shortBreakDuration * 60
        case .longBreak: return settings.longBreakDuration * 60
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
            if elapsed >= 60 { // save only if at least 1 minute
                saveSession(startedAt: start, duration: elapsed, type: sessionTypeForPhase())
            }
        }
        timerState = .idle
        sessionStart = nil
        resetToCurrentPhase()
    }

    // MARK: - Private

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
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
        case .focus: return .focus
        case .shortBreak: return .shortBreak
        case .longBreak: return .longBreak
        }
    }

    private func saveSession(startedAt: Date, duration: TimeInterval, type: SessionType) {
        let session = StudySession(startedAt: startedAt, duration: duration, type: type)
        modelContext.insert(session)
        try? modelContext.save()
    }

    private func playCompletionSound() {
        guard settings.soundEnabled else { return }
        NSSound(named: "Glass")?.play()
    }
}
```

**Step 2: Build — Cmd+B. Fix any compilation errors.**

**Step 3: Commit**

```bash
git add StatFocus/ViewModels/TimerViewModel.swift
git commit -m "feat: TimerViewModel with Pomodoro state machine"
```

---

## Task 4: Timer Window UI

**Files:**
- Create: `StatFocus/Views/Timer/TimerView.swift`
- Create: `StatFocus/Views/Timer/CycleDotsView.swift`
- Create: `StatFocus/Views/Timer/TimerControlsView.swift`

**Step 1: Create `CycleDotsView.swift`**

```swift
// StatFocus/Views/Timer/CycleDotsView.swift
import SwiftUI

struct CycleDotsView: View {
    let total: Int
    let completed: Int
    let accentColor = Color(hex: "#2D6A4F")

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i < completed ? accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}
```

**Step 2: Create `TimerControlsView.swift`**

```swift
// StatFocus/Views/Timer/TimerControlsView.swift
import SwiftUI

struct TimerControlsView: View {
    @Bindable var viewModel: TimerViewModel  // requires @Observable
    let accent = Color(hex: "#2D6A4F")

    var body: some View {
        HStack(spacing: 20) {
            if viewModel.timerState == .running || viewModel.timerState == .paused {
                // Stop button
                Button {
                    viewModel.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Play / Pause button
            Button {
                if viewModel.timerState == .running {
                    viewModel.pause()
                } else {
                    viewModel.play()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: viewModel.timerState == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(accent)
                        .offset(x: viewModel.timerState == .running ? 0 : 2)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
```

**Step 3: Create `TimerView.swift`**

```swift
// StatFocus/Views/Timer/TimerView.swift
import SwiftUI

struct TimerView: View {
    @Bindable var viewModel: TimerViewModel
    let onOpenDashboard: () -> Void
    let accent = Color(hex: "#2D6A4F")

    var phaseLabel: String {
        switch viewModel.phase {
        case .focus: return "StatFocus"
        case .shortBreak: return "Pausa"
        case .longBreak: return "Pausa Longa"
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Dashboard button
            Button {
                onOpenDashboard()
            } label: {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(14)

            // Main content
            VStack(spacing: 12) {
                Text(phaseLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                Text(viewModel.timeString)
                    .font(.system(size: 64, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)

                CycleDotsView(
                    total: viewModel.cycleCount,
                    completed: viewModel.completedCycles % viewModel.cycleCount
                )

                TimerControlsView(viewModel: viewModel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
        .frame(width: 300, height: 220)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

**Step 4: Add Color hex extension**

Create `StatFocus/Utilities/Color+Hex.swift`:

```swift
// StatFocus/Utilities/Color+Hex.swift
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

**Step 5: Build and run — verify floating window appears with timer**

**Step 6: Commit**

```bash
git add StatFocus/Views/Timer/ StatFocus/Utilities/
git commit -m "feat: timer window UI with cycle dots and controls"
```

---

## Task 5: Statistics ViewModel

**Files:**
- Create: `StatFocus/ViewModels/StatsViewModel.swift`
- Create: `StatFocus/Utilities/DateHelpers.swift`

**Step 1: Create `DateHelpers.swift`**

```swift
// StatFocus/Utilities/DateHelpers.swift
import Foundation

extension Calendar {
    static var current: Calendar { Calendar.autoupdatingCurrent }

    func startOfDay(for date: Date) -> Date {
        self.startOfDay(for: date)
    }

    func startOfWeek(for date: Date) -> Date {
        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: comps) ?? date
    }

    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }

    func isDate(_ date1: Date, sameDayAs date2: Date) -> Bool {
        isDate(date1, inSameDayAs: date2)
    }
}

extension Date {
    var dayStart: Date { Calendar.autoupdatingCurrent.startOfDay(for: self) }

    func adding(days: Int) -> Date {
        Calendar.autoupdatingCurrent.date(byAdding: .day, value: days, to: self) ?? self
    }
}
```

**Step 2: Create `StatsViewModel.swift`**

```swift
// StatFocus/ViewModels/StatsViewModel.swift
import Foundation
import SwiftData

@Observable
class StatsViewModel {
    private var modelContext: ModelContext
    var sessions: [StudySession] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadSessions()
    }

    func loadSessions() {
        let descriptor = FetchDescriptor<StudySession>(
            sortBy: [SortDescriptor(\.startedAt)]
        )
        sessions = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Heatmap

    /// Returns hours studied for each day in the last 365 days
    func heatmapData() -> [(date: Date, hours: Double)] {
        let today = Date().dayStart
        let startDate = today.adding(days: -364)

        var result: [(date: Date, hours: Double)] = []
        var current = startDate

        while current <= today {
            let hours = focusHours(for: current)
            result.append((date: current, hours: hours))
            current = current.adding(days: 1)
        }
        return result
    }

    func focusHours(for day: Date) -> Double {
        let cal = Calendar.autoupdatingCurrent
        let focusSessions = sessions.filter {
            $0.type == .focus && cal.isDate($0.startedAt, sameDayAs: day)
        }
        let totalSeconds = focusSessions.reduce(0) { $0 + $1.duration }
        return totalSeconds / 3600
    }

    // MARK: - Streak

    var currentStreak: Int {
        let today = Date().dayStart
        var streak = 0
        var day = today
        while focusHours(for: day) > 0 {
            streak += 1
            day = day.adding(days: -1)
        }
        return streak
    }

    var bestStreak: Int {
        guard !sessions.isEmpty else { return 0 }
        let cal = Calendar.autoupdatingCurrent
        let allDays = Set(sessions.filter { $0.type == .focus }
            .map { cal.startOfDay(for: $0.startedAt) })
            .sorted()

        var best = 0, current = 0
        var prev: Date? = nil
        for day in allDays {
            if let p = prev, cal.dateComponents([.day], from: p, to: day).day == 1 {
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

    var todayFocusHours: Double {
        focusHours(for: Date().dayStart)
    }

    var weekFocusHours: Double {
        let startOfWeek = Calendar.autoupdatingCurrent.startOfWeek(for: Date())
        let focusSessions = sessions.filter {
            $0.type == .focus && $0.startedAt >= startOfWeek
        }
        return focusSessions.reduce(0) { $0 + $1.duration } / 3600
    }

    // MARK: - Bar Chart

    enum ChartPeriod { case day, week, month, year }

    func barChartData(period: ChartPeriod) -> [(label: String, hours: Double)] {
        let cal = Calendar.autoupdatingCurrent
        switch period {
        case .day:
            // Last 7 days
            return (0..<7).reversed().map { offset in
                let day = Date().dayStart.adding(days: -offset)
                let label = cal.shortWeekdaySymbols[cal.component(.weekday, from: day) - 1]
                return (label: label, hours: focusHours(for: day))
            }
        case .week:
            // Last 8 weeks
            return (0..<8).reversed().map { offset in
                let weekStart = cal.date(byAdding: .weekOfYear, value: -offset,
                                         to: cal.startOfWeek(for: Date()))!
                let weekEnd = weekStart.adding(days: 7)
                let hours = sessions.filter {
                    $0.type == .focus && $0.startedAt >= weekStart && $0.startedAt < weekEnd
                }.reduce(0) { $0 + $1.duration } / 3600
                let weekNum = cal.component(.weekOfYear, from: weekStart)
                return (label: "S\(weekNum)", hours: hours)
            }
        case .month:
            // Last 12 months
            return (0..<12).reversed().map { offset in
                let monthStart = cal.date(byAdding: .month, value: -offset,
                                           to: cal.startOfMonth(for: Date()))!
                let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)!
                let hours = sessions.filter {
                    $0.type == .focus && $0.startedAt >= monthStart && $0.startedAt < monthEnd
                }.reduce(0) { $0 + $1.duration } / 3600
                let label = cal.shortMonthSymbols[cal.component(.month, from: monthStart) - 1]
                return (label: label, hours: hours)
            }
        case .year:
            // Last 5 years
            let currentYear = cal.component(.year, from: Date())
            return (0..<5).reversed().map { offset in
                let year = currentYear - offset
                let comps = DateComponents(year: year)
                let yearStart = cal.date(from: comps)!
                let yearEnd = cal.date(byAdding: .year, value: 1, to: yearStart)!
                let hours = sessions.filter {
                    $0.type == .focus && $0.startedAt >= yearStart && $0.startedAt < yearEnd
                }.reduce(0) { $0 + $1.duration } / 3600
                return (label: "\(year)", hours: hours)
            }
        }
    }
}
```

**Step 3: Build — Cmd+B**

**Step 4: Commit**

```bash
git add StatFocus/ViewModels/StatsViewModel.swift StatFocus/Utilities/DateHelpers.swift
git commit -m "feat: StatsViewModel with heatmap, streak, goals, and bar chart data"
```

---

## Task 6: Heatmap View

**Files:**
- Create: `StatFocus/Views/Dashboard/HeatmapView.swift`

**Step 1: Create `HeatmapView.swift`**

```swift
// StatFocus/Views/Dashboard/HeatmapView.swift
import SwiftUI

struct HeatmapView: View {
    let data: [(date: Date, hours: Double)]
    let maxHours: Double
    let accent = Color(hex: "#2D6A4F")

    @State private var hoveredDate: Date? = nil

    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 3
    private let columns = 52
    private let rows = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Atividade do Ano")
                .font(.headline)

            // Month labels
            HStack(spacing: 0) {
                ForEach(monthOffsets(), id: \.0) { (label, col) in
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: CGFloat(col) * (cellSize + cellSpacing), alignment: .leading)
                }
            }

            // Grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cellSize), spacing: cellSpacing), count: columns),
                spacing: cellSpacing
            ) {
                ForEach(paddedData(), id: \.0) { (idx, item) in
                    if let item = item {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(cellColor(hours: item.hours))
                            .frame(width: cellSize, height: cellSize)
                            .help("\(formattedDate(item.date)): \(String(format: "%.1f", item.hours))h")
                    } else {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.clear)
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }

            // Legend
            HStack(spacing: 4) {
                Text("Menos")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(intensity == 0 ? Color.gray.opacity(0.15) : accent.opacity(intensity))
                        .frame(width: cellSize, height: cellSize)
                }
                Text("Mais")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func cellColor(hours: Double) -> Color {
        guard hours > 0, maxHours > 0 else { return Color.gray.opacity(0.12) }
        let intensity = min(hours / maxHours, 1.0)
        // 4 levels like GitHub
        let level = ceil(intensity * 4) / 4
        return accent.opacity(0.2 + level * 0.8)
    }

    /// Pad data so index 0 = Sunday of the first week
    private func paddedData() -> [(Int, (date: Date, hours: Double)?)] {
        guard let first = data.first else { return [] }
        let cal = Calendar.autoupdatingCurrent
        let weekday = cal.component(.weekday, from: first.date) - 1 // 0=Sun
        var result: [(Int, (date: Date, hours: Double)?)] = []
        var idx = 0
        for _ in 0..<weekday {
            result.append((idx, nil))
            idx += 1
        }
        for item in data {
            result.append((idx, item))
            idx += 1
        }
        // Pad to full grid
        while result.count % columns != 0 {
            result.append((idx, nil))
            idx += 1
        }
        return result
    }

    private func monthOffsets() -> [(String, Int)] {
        guard !data.isEmpty else { return [] }
        var result: [(String, Int)] = []
        let cal = Calendar.autoupdatingCurrent
        var lastMonth = -1
        let firstWeekday = cal.component(.weekday, from: data[0].date) - 1
        for (dayIdx, item) in data.enumerated() {
            let month = cal.component(.month, from: item.date)
            if month != lastMonth {
                let col = (dayIdx + firstWeekday) / 7
                let label = cal.shortMonthSymbols[month - 1]
                result.append((label, col))
                lastMonth = month
            }
        }
        return result
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}
```

**Step 2: Build — Cmd+B**

**Step 3: Commit**

```bash
git add StatFocus/Views/Dashboard/HeatmapView.swift
git commit -m "feat: GitHub-style annual heatmap view"
```

---

## Task 7: Stats Components (Streak, Goals, Bar Chart)

**Files:**
- Create: `StatFocus/Views/Dashboard/StreakView.swift`
- Create: `StatFocus/Views/Dashboard/GoalsView.swift`
- Create: `StatFocus/Views/Components/CircularProgressView.swift`
- Create: `StatFocus/Views/Dashboard/BarChartView.swift`

**Step 1: Create `CircularProgressView.swift`**

```swift
// StatFocus/Views/Components/CircularProgressView.swift
import SwiftUI

struct CircularProgressView: View {
    let progress: Double  // 0.0 to 1.0
    let label: String
    let sublabel: String
    let accent = Color(hex: "#2D6A4F")

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.12), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                VStack(spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 18, weight: .semibold))
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, height: 80)
            Text(sublabel)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
```

**Step 2: Create `StreakView.swift`**

```swift
// StatFocus/Views/Dashboard/StreakView.swift
import SwiftUI

struct StreakView: View {
    let current: Int
    let best: Int
    let accent = Color(hex: "#2D6A4F")

    var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.title2)
                    Text("\(current)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(accent)
                }
                Text("dias seguidos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider().frame(height: 48)

            VStack(spacing: 4) {
                Text("\(best)")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("recorde")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

**Step 3: Create `GoalsView.swift`**

```swift
// StatFocus/Views/Dashboard/GoalsView.swift
import SwiftUI

struct GoalsView: View {
    let todayHours: Double
    let dailyGoal: Double
    let weekHours: Double
    let weeklyGoal: Double
    let accent = Color(hex: "#2D6A4F")

    var dailyProgress: Double { min(todayHours / max(dailyGoal, 0.001), 1.0) }
    var weeklyProgress: Double { min(weekHours / max(weeklyGoal, 0.001), 1.0) }

    var body: some View {
        HStack(spacing: 32) {
            CircularProgressView(
                progress: dailyProgress,
                label: "hoje",
                sublabel: "\(formattedHours(todayHours)) / \(formattedHours(dailyGoal))"
            )

            CircularProgressView(
                progress: weeklyProgress,
                label: "semana",
                sublabel: "\(formattedHours(weekHours)) / \(formattedHours(weeklyGoal))"
            )
        }
    }

    private func formattedHours(_ h: Double) -> String {
        let hours = Int(h)
        let minutes = Int((h - Double(hours)) * 60)
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }
}
```

**Step 4: Create `BarChartView.swift`**

```swift
// StatFocus/Views/Dashboard/BarChartView.swift
import SwiftUI

struct BarChartView: View {
    let data: [(label: String, hours: Double)]
    let accent = Color(hex: "#2D6A4F")

    var maxHours: Double { data.map(\.hours).max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data.indices, id: \.self) { i in
                    VStack(spacing: 4) {
                        if data[i].hours > 0 {
                            Text(String(format: "%.1f", data[i].hours))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(accent.opacity(0.8))
                            .frame(
                                width: 28,
                                height: max(4, CGFloat(data[i].hours / max(maxHours, 0.001)) * 120)
                            )
                            .animation(.easeInOut(duration: 0.4), value: data[i].hours)
                        Text(data[i].label)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
```

**Step 5: Build — Cmd+B**

**Step 6: Commit**

```bash
git add StatFocus/Views/Dashboard/ StatFocus/Views/Components/
git commit -m "feat: streak, goals, and bar chart stat components"
```

---

## Task 8: Dashboard Window

**Files:**
- Create: `StatFocus/Views/Dashboard/StatsView.swift`
- Create: `StatFocus/Views/Dashboard/SettingsView.swift`
- Create: `StatFocus/Views/Dashboard/DashboardView.swift`

**Step 1: Create `StatsView.swift`**

```swift
// StatFocus/Views/Dashboard/StatsView.swift
import SwiftUI

struct StatsView: View {
    @Bindable var viewModel: StatsViewModel
    @State private var chartPeriod: StatsViewModel.ChartPeriod = .day

    var heatmapData: [(date: Date, hours: Double)] { viewModel.heatmapData() }
    var maxHours: Double { heatmapData.map(\.hours).max() ?? 1 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Streak
                StreakView(current: viewModel.currentStreak, best: viewModel.bestStreak)

                // Goals
                VStack(alignment: .leading, spacing: 8) {
                    Text("Metas")
                        .font(.headline)
                    GoalsView(
                        todayHours: viewModel.todayFocusHours,
                        dailyGoal: AppSettings.shared.dailyGoalHours,
                        weekHours: viewModel.weekFocusHours,
                        weeklyGoal: AppSettings.shared.weeklyGoalHours
                    )
                }

                // Heatmap
                HeatmapView(data: heatmapData, maxHours: maxHours)

                // Bar Chart
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Horas de Foco")
                            .font(.headline)
                        Spacer()
                        Picker("Período", selection: $chartPeriod) {
                            Text("Dia").tag(StatsViewModel.ChartPeriod.day)
                            Text("Semana").tag(StatsViewModel.ChartPeriod.week)
                            Text("Mês").tag(StatsViewModel.ChartPeriod.month)
                            Text("Ano").tag(StatsViewModel.ChartPeriod.year)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 240)
                    }
                    BarChartView(data: viewModel.barChartData(period: chartPeriod))
                }
            }
            .padding(24)
        }
        .onAppear { viewModel.loadSessions() }
    }
}
```

**Step 2: Create `SettingsView.swift`**

```swift
// StatFocus/Views/Dashboard/SettingsView.swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Timer") {
                Stepper("Foco: \(settings.focusDuration) min",
                        value: $settings.focusDuration, in: 5...90, step: 5)
                Stepper("Pausa curta: \(settings.shortBreakDuration) min",
                        value: $settings.shortBreakDuration, in: 1...30, step: 1)
                Stepper("Pausa longa: \(settings.longBreakDuration) min",
                        value: $settings.longBreakDuration, in: 5...60, step: 5)
                Stepper("Ciclos até pausa longa: \(settings.cyclesBeforeLongBreak)",
                        value: $settings.cyclesBeforeLongBreak, in: 2...8, step: 1)
            }

            Section("Metas") {
                HStack {
                    Text("Meta diária")
                    Spacer()
                    TextField("h", value: $settings.dailyGoalHours, format: .number)
                        .frame(width: 60)
                    Text("horas")
                }
                HStack {
                    Text("Meta semanal")
                    Spacer()
                    TextField("h", value: $settings.weeklyGoalHours, format: .number)
                        .frame(width: 60)
                    Text("horas")
                }
            }

            Section("Geral") {
                Toggle("Som de notificação", isOn: $settings.soundEnabled)
                Toggle("Iniciar no login", isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { enabled in
                        if enabled {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }
                ))
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

**Step 3: Create `DashboardView.swift`**

```swift
// StatFocus/Views/Dashboard/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @Bindable var statsViewModel: StatsViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            StatsView(viewModel: statsViewModel)
                .tabItem {
                    Label("Estatísticas", systemImage: "chart.bar.fill")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label("Configurações", systemImage: "gear")
                }
                .tag(1)
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}
```

**Step 4: Build and run — open Dashboard from timer window**

**Step 5: Commit**

```bash
git add StatFocus/Views/Dashboard/
git commit -m "feat: dashboard with stats and settings tabs"
```

---

## Task 9: Polish & UX Refinements

**Files:**
- Modify: `StatFocus/Views/Timer/TimerView.swift`
- Modify: `StatFocus/App/AppDelegate.swift`

**Step 1: Add keyboard shortcut to show/hide timer**

Add to `AppDelegate.swift`:

```swift
// In applicationDidFinishLaunching, after setupTimerPanel():
NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
    // Cmd+Shift+F to toggle timer window
    if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 3 {
        DispatchQueue.main.async {
            self?.toggleTimerPanel()
        }
    }
}

func toggleTimerPanel() {
    guard let panel = timerPanel else { return }
    if panel.isVisible {
        panel.orderOut(nil)
    } else {
        panel.makeKeyAndOrderFront(nil)
    }
}
```

**Step 2: Add phase color transition to timer display**

In `TimerView.swift`, update timer text color based on phase:

```swift
var phaseColor: Color {
    switch viewModel.phase {
    case .focus: return .primary
    case .shortBreak: return Color(hex: "#52B788")
    case .longBreak: return Color(hex: "#40916C")
    }
}
// Apply to timer text: .foregroundColor(phaseColor)
```

**Step 3: Add app icon**

Add a 1024×1024 app icon to `Assets.xcassets/AppIcon`. Use a green circle with a stylized timer or focus symbol. (Use SF Symbols "timer" or design custom.)

**Step 4: Build, run full flow end-to-end:**
- Start timer → let it complete → verify session saved
- Open Dashboard → verify stats appear
- Change settings → verify timer reflects new duration

**Step 5: Commit**

```bash
git add .
git commit -m "feat: keyboard shortcut, phase colors, app icon"
```

---

## Task 10: Final Integration & Smoke Test

**Step 1: Full end-to-end test checklist**

```
□ App launches without Dock icon (timer floats)
□ Timer starts, pauses, stops correctly
□ Session saved after stop (minimum 60 seconds)
□ Cycle dots advance correctly
□ After N focus cycles → long break triggered
□ Completion sound plays (check macOS sound settings)
□ Dashboard opens from timer button
□ Heatmap renders (may need fake data for today)
□ Streak shows 1 after first completed session
□ Goals show current progress
□ Bar chart D tab shows today's hours
□ Settings: changing focus duration updates timer on next reset
□ Launch at login toggle works
□ Dashboard closes → no Dock icon remains
```

**Step 2: Seed fake data for testing stats (optional, dev only)**

Add a debug button in SettingsView:

```swift
#if DEBUG
Button("Seed Test Data") {
    seedTestData()
}

func seedTestData() {
    let context = /* get modelContext */
    for dayOffset in 0..<30 {
        let date = Date().adding(days: -dayOffset)
        let sessions = Int.random(in: 2...6)
        for _ in 0..<sessions {
            let session = StudySession(
                startedAt: date,
                duration: Double.random(in: 1200...3000),
                type: .focus
            )
            context.insert(session)
        }
    }
    try? context.save()
}
#endif
```

**Step 3: Final commit**

```bash
git add .
git commit -m "feat: complete StatFocus v1 — Pomodoro timer with stats dashboard"
```

---

## Verification

After completing all tasks, verify end-to-end:

1. **Build**: `Cmd+B` — zero errors, zero warnings
2. **Run**: App launches, floating timer appears, no Dock icon
3. **Timer flow**: Play → 25 min countdown → auto-switches to break → saves session
4. **Stats**: Open Dashboard → heatmap shows today → streak shows 1+ → goals update
5. **Settings**: Change focus to 5 min → stop → restart → new duration shown
6. **Persistence**: Quit app → relaunch → Dashboard shows historical data

---

## Notes for Implementer

- **`@Observable` vs `@ObservedObject`**: Use `@Observable` (Swift 5.9 Observation framework) for ViewModels, `@ObservedObject` only for `AppSettings` which uses Combine/`@Published`.
- **`@Bindable`**: Required in SwiftUI views that need two-way binding to `@Observable` objects.
- **NSPanel level**: `.floating` keeps the window above normal windows but below system UI. Use `.screenSaver` only if you want it above everything.
- **SwiftData context**: Pass `modelContainer.mainContext` — don't create new contexts per view.
- **Heatmap grid rotation**: The LazyVGrid fills left-to-right, top-to-bottom. We need columns (weeks) left-to-right with days (Sun-Sat) top-to-bottom. The paddedData() function handles the alignment by offsetting the first day to its correct weekday row.
