// StatFocus/Views/Timer/TimerView.swift
import SwiftUI

struct TimerView: View {
    @Bindable var viewModel: TimerViewModel
    let onOpenDashboard: () -> Void

    var phaseLabel: String {
        switch viewModel.phase {
        case .focus: return "StatFocus"
        case .shortBreak: return "Pausa"
        case .longBreak: return "Pausa Longa"
        }
    }

    var phaseColor: Color {
        switch viewModel.phase {
        case .focus: return .primary
        case .shortBreak: return Color(hex: "#52B788")
        case .longBreak: return Color(hex: "#40916C")
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Dashboard open button (top-right)
            Button {
                onOpenDashboard()
            } label: {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(14)
            }
            .buttonStyle(.plain)

            // Main content centered
            VStack(spacing: 14) {
                Text(phaseLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .animation(.easeInOut, value: phaseLabel)

                Text(viewModel.timeString)
                    .font(.system(size: 62, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(phaseColor)
                    .animation(.easeInOut(duration: 0.4), value: phaseColor == .primary)
                    .contentTransition(.numericText(countsDown: true))

                CycleDotsView(
                    total: viewModel.cycleCount,
                    completed: viewModel.completedCycles % max(1, viewModel.cycleCount)
                )

                TimerControlsView(viewModel: viewModel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 20)
        }
        .frame(width: 300, height: 220)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
