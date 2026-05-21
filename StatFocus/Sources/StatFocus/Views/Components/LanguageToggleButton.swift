// StatFocus/Views/Components/LanguageToggleButton.swift
import SwiftUI

struct LanguageToggleButton: View {
    private let loc = LocalizationManager.shared

    var body: some View {
        Button(action: { loc.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 11, weight: .medium))
                Text(loc.currentLanguage.shortLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .help(loc.t("lang.toggle.help"))
    }
}
