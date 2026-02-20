// StatFocus/Views/Dashboard/SettingsView.swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Timer") {
                Stepper(
                    "Foco: \(settings.focusDuration) min",
                    value: $settings.focusDuration,
                    in: 5...90,
                    step: 5
                )
                Stepper(
                    "Pausa curta: \(settings.shortBreakDuration) min",
                    value: $settings.shortBreakDuration,
                    in: 1...30,
                    step: 1
                )
                Stepper(
                    "Pausa longa: \(settings.longBreakDuration) min",
                    value: $settings.longBreakDuration,
                    in: 5...60,
                    step: 5
                )
                Stepper(
                    "Ciclos até pausa longa: \(settings.cyclesBeforeLongBreak)",
                    value: $settings.cyclesBeforeLongBreak,
                    in: 2...8,
                    step: 1
                )
            }

            Section("Metas") {
                HStack {
                    Text("Meta diária")
                    Spacer()
                    TextField("horas", value: $settings.dailyGoalHours, format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                    Text("horas")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Meta semanal")
                    Spacer()
                    TextField("horas", value: $settings.weeklyGoalHours, format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                    Text("horas")
                        .foregroundColor(.secondary)
                }
            }

            Section("Geral") {
                Toggle("Som de notificação", isOn: $settings.soundEnabled)

                Toggle("Iniciar no login", isOn: Binding(
                    get: {
                        SMAppService.mainApp.status == .enabled
                    },
                    set: { shouldEnable in
                        do {
                            if shouldEnable {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("SMAppService error: \(error)")
                        }
                    }
                ))
            }

            #if DEBUG
            Section("Desenvolvimento") {
                Button("Gerar dados de teste (60 dias)") {
                    // Accessed via model container from environment
                    NotificationCenter.default.post(
                        name: .init("SeedTestData"),
                        object: nil
                    )
                }
                .foregroundColor(.orange)
            }
            #endif
        }
        .formStyle(.grouped)
    }
}
