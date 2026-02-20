// StatFocus/Views/Timer/CycleDotsView.swift
import SwiftUI

struct CycleDotsView: View {
    let total: Int
    let completed: Int
    let accentColor = Color(hex: "#2D6A4F")

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<max(1, total), id: \.self) { i in
                Circle()
                    .fill(i < completed ? accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: completed)
            }
        }
    }
}
