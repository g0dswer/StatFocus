// StatFocus/Models/StudySession.swift
// Persistence: JSON file in Application Support (no SwiftData macros needed).
// To migrate to SwiftData later: replace with @Model class and update SessionStore.
import Foundation

enum SessionType: String, Codable {
    case focus
    case shortBreak
    case longBreak
}

struct StudySession: Codable, Identifiable {
    var id: UUID
    var startedAt: Date
    var duration: TimeInterval  // seconds
    var type: SessionType

    init(startedAt: Date, duration: TimeInterval, type: SessionType) {
        self.id = UUID()
        self.startedAt = startedAt
        self.duration = duration
        self.type = type
    }
}
