// StatFocus/Views/Timer/TimerControlsView.swift
import SwiftUI

struct TimerControlsView: View {
    @Bindable var viewModel: TimerViewModel
    let accent = Color(hex: "#2D6A4F")

    var body: some View {
        HStack(spacing: 20) {
            // Stop button — only visible when running or paused
            if viewModel.timerState == .running || viewModel.timerState == .paused {
                Button {
                    viewModel.stop()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.08))
                            .frame(width: 36, height: 36)
                        Image(systemName: "stop.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
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
        .animation(.spring(response: 0.3), value: viewModel.timerState == .idle)
    }
}
