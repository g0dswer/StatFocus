// StatFocus/Views/Components/CircularProgressView.swift
import SwiftUI

struct CircularProgressView: View {
    let progress: Double  // 0.0 to 1.0
    let label: String
    let sublabel: String
    let accent = Color(hex: "#2D6A4F")

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background track
                Circle()
                    .stroke(accent.opacity(0.12), lineWidth: 8)

                // Progress arc
                Circle()
                    .trim(from: 0, to: clampedProgress)
                    .stroke(
                        accent,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: clampedProgress)

                // Center text
                VStack(spacing: 1) {
                    Text("\(Int(clampedProgress * 100))%")
                        .font(.system(size: 16, weight: .semibold))
                        .contentTransition(.numericText())
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            Text(sublabel)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 100)
        }
    }
}
