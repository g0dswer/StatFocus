// StatFocus/Views/Timer/TimerView.swift
import SwiftUI

struct TimerView: View {
    @Bindable var viewModel: TimerViewModel
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var totalFocusState = TotalFocusState.shared
    let onOpenDashboard: () -> Void
    let onCloseTimer: () -> Void

    private let focusOptions = [15, 20, 25, 30, 45, 50, 60, 90]
    private let shortBreakOptions = [3, 5, 10, 15, 20, 25, 30]
    private let dailyGoalOptions = [2.0, 3.0, 4.0, 5.0, 6.0, 8.0]
    private let weeklyGoalOptions = [10.0, 15.0, 20.0, 25.0, 30.0, 40.0]
    private let loc = LocalizationManager.shared

    var phaseLabel: String {
        switch viewModel.phase {
        case .focus: return loc.t("timer.phase.focus")
        case .shortBreak: return loc.t("timer.phase.break")
        }
    }

    var phaseColor: Color {
        switch viewModel.phase {
        case .focus: return .primary
        case .shortBreak: return Color(hex: "#52B788")
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let shortestSide = min(proxy.size.width, proxy.size.height)
            let phaseFontSize = max(16, shortestSide * 0.075)
            let timeFontSize = max(60, shortestSide * 0.34)
            let iconFontSize = max(14, shortestSide * 0.06)
            let settingsLocked = totalFocusState.isLockActive

            VStack(spacing: 0) {
                HStack {
                    Button {
                        if !totalFocusState.isLockActive {
                            onCloseTimer()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.28))
                                .frame(width: 14, height: 14)
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.96))
                        }
                    }
                    .buttonStyle(.plain)
                    .help(totalFocusState.isLockActive ? loc.t("timer.help.lock_close") : "")

                    Spacer()

                    HStack(spacing: 14) {
                        Button {
                            viewModel.resetCountdown()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: iconFontSize, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(loc.t("timer.help.reset"))

                        Button {
                            onOpenDashboard()
                        } label: {
                            Image(systemName: "chart.bar")
                                .font(.system(size: iconFontSize, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)

                        Menu {
                            Menu(loc.t("timer.menu.focus_duration")) {
                                ForEach(focusOptions, id: \.self) { minutes in
                                    Button {
                                        settings.focusDuration = minutes
                                        viewModel.applySettingsIfIdle()
                                    } label: {
                                        HStack {
                                            Text("\(minutes) min")
                                            if settings.focusDuration == minutes {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                            .disabled(settingsLocked)

                            Menu(loc.t("timer.menu.break_duration")) {
                                ForEach(shortBreakOptions, id: \.self) { minutes in
                                    Button {
                                        settings.shortBreakDuration = minutes
                                        viewModel.applySettingsIfIdle()
                                    } label: {
                                        HStack {
                                            Text("\(minutes) min")
                                            if settings.shortBreakDuration == minutes {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                            .disabled(settingsLocked)

                            Menu(loc.t("timer.menu.daily_goal")) {
                                ForEach(dailyGoalOptions, id: \.self) { hours in
                                    Button {
                                        settings.dailyGoalHours = hours
                                    } label: {
                                        HStack {
                                            Text("\(Int(hours))h")
                                            if abs(settings.dailyGoalHours - hours) < 0.001 {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                            .disabled(settingsLocked)

                            Menu(loc.t("timer.menu.weekly_goal")) {
                                ForEach(weeklyGoalOptions, id: \.self) { hours in
                                    Button {
                                        settings.weeklyGoalHours = hours
                                    } label: {
                                        HStack {
                                            Text("\(Int(hours))h")
                                            if abs(settings.weeklyGoalHours - hours) < 0.001 {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                            .disabled(settingsLocked)

                            Divider()
                            Toggle(loc.t("timer.menu.sound"), isOn: $settings.soundEnabled).disabled(settingsLocked)
                            Toggle(loc.t("timer.menu.auto_hide"), isOn: $settings.autoHideDuringFocus).disabled(settingsLocked)
                            Toggle(loc.t("timer.menu.total_focus"), isOn: $settings.totalFocusEnabled).disabled(settingsLocked)
                            Divider()

                            Button(loc.t("timer.menu.open_settings")) {
                                onOpenDashboard()
                            }

                            Button(loc.t("timer.menu.hide_timer")) {
                                onCloseTimer()
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: iconFontSize, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                Spacer(minLength: 8)

                Text(phaseLabel)
                    .font(.system(size: phaseFontSize, weight: .medium))
                    .foregroundColor(.secondary)
                    .animation(.easeInOut, value: phaseLabel)

                Text(viewModel.timeString)
                    .font(.system(size: timeFontSize, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(phaseColor)
                    .animation(.easeInOut(duration: 0.4), value: phaseColor == .primary)
                    .contentTransition(.numericText(countsDown: true))

                CycleDotsView(
                    total: viewModel.cycleCount,
                    completed: viewModel.completedCycles % max(1, viewModel.cycleCount)
                )
                .padding(.top, 2)

                TimerControlsView(viewModel: viewModel)
                    .padding(.top, 12)

                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .ignoresSafeArea()
    }
}
