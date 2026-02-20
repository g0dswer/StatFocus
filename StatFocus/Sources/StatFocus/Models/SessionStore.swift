// StatFocus/Models/SessionStore.swift
// Lightweight JSON persistence for study sessions.
// Replaces SwiftData ModelContainer/ModelContext for CLT-only builds.
import Foundation

final class SessionStore {
    static let shared = SessionStore()

    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("StatFocus", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("sessions.json")
    }

    // MARK: - Public API

    func loadAll() -> [StudySession] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([StudySession].self, from: data)) ?? []
    }

    func save(_ sessions: [StudySession]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(sessions) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func insert(_ session: StudySession) {
        var all = loadAll()
        all.append(session)
        save(all)
    }

    /// Delete all sessions (useful for testing)
    func deleteAll() {
        save([])
    }
}
