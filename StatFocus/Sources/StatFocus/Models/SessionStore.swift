// StatFocus/Models/SessionStore.swift
// Lightweight JSON persistence for study sessions.
// Replaces SwiftData ModelContainer/ModelContext for CLT-only builds.
import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers

final class SessionStore {
    static let shared = SessionStore()

    private let fileURL: URL

    private convenience init() {
        self.init(fileURL: SessionStore.defaultFileURL())
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private static func defaultFileURL() -> URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("StatFocus", isDirectory: true)
            .appendingPathComponent("sessions.json")
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

struct UserDataBackupPayload: Codable {
    let version: Int
    let exportedAt: Date
    let sessions: [StudySession]
}

enum UserDataBackupCodec {
    static let currentVersion = 1
    static let fileExtension = "statfocusbackup"
    static let latestBackupFileName = "StatFocus-user-data-latest.\(fileExtension)"

    static func encode(sessions: [StudySession], exportedAt: Date = Date()) throws -> Data {
        let payload = UserDataBackupPayload(
            version: currentVersion,
            exportedAt: exportedAt,
            sessions: sessions
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    static func decodeSessions(from data: Data) throws -> [StudySession] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let payload = try? decoder.decode(UserDataBackupPayload.self, from: data) {
            return payload.sessions
        }
        if let sessions = try? decoder.decode([StudySession].self, from: data) {
            return sessions
        }
        throw BackupError.invalidBackupFile
    }
}

enum BackupError: LocalizedError {
    case noBackupFolderSelected
    case invalidBackupFile
    case cannotCreateBackupDirectory
    case cannotWriteBackup
    case cannotReadBackup

    var errorDescription: String? {
        switch self {
        case .noBackupFolderSelected:    return L.t("backup.errors.no_folder")
        case .invalidBackupFile:         return L.t("backup.errors.invalid_file")
        case .cannotCreateBackupDirectory: return L.t("backup.errors.cannot_create")
        case .cannotWriteBackup:         return L.t("backup.errors.cannot_write")
        case .cannotReadBackup:          return L.t("backup.errors.cannot_read")
        }
    }
}

@MainActor
final class BackupManager: ObservableObject {
    static let shared = BackupManager()

    @Published private(set) var autoBackupEnabled: Bool
    @Published private(set) var backupFolderPath: String
    @Published private(set) var lastBackupAt: Date?
    @Published private(set) var statusMessage: String = ""
    @Published private(set) var statusIsError: Bool = false

    private let store: SessionStore
    private let defaults: UserDefaults
    private var sessionsObserver: NSObjectProtocol?

    private let autoBackupKey = "backup.auto.enabled"
    private let backupFolderPathKey = "backup.folder.path"
    private let backupFolderBookmarkKey = "backup.folder.bookmark"
    private let lastBackupAtKey = "backup.lastSavedAt"

    private init(store: SessionStore = .shared, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        self.autoBackupEnabled = defaults.bool(forKey: autoBackupKey)
        self.backupFolderPath = defaults.string(forKey: backupFolderPathKey) ?? ""
        self.lastBackupAt = defaults.object(forKey: lastBackupAtKey) as? Date

        sessionsObserver = NotificationCenter.default.addObserver(
            forName: .sessionsUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSessionsUpdated()
            }
        }
    }

    deinit {
        if let sessionsObserver {
            NotificationCenter.default.removeObserver(sessionsObserver)
        }
    }

    var hasBackupFolderConfigured: Bool {
        !backupFolderPath.isEmpty
    }

    func setAutoBackupEnabled(_ enabled: Bool) {
        autoBackupEnabled = enabled
        defaults.set(enabled, forKey: autoBackupKey)

        guard enabled else {
            showSuccess(L.t("backup.status.auto_disabled"))
            return
        }

        if !hasBackupFolderConfigured {
            chooseBackupFolder()
            if !hasBackupFolderConfigured {
                autoBackupEnabled = false
                defaults.set(false, forKey: autoBackupKey)
                showError(L.t("backup.status.no_folder"))
                return
            }
        }

        do {
            _ = try writeBackupFile()
            showSuccess(L.t("backup.status.auto_enabled"))
        } catch {
            showError(error.localizedDescription)
        }
    }

    func chooseBackupFolder() {
        let panel = NSOpenPanel()
        panel.title = "Escolha a pasta de backup"
        panel.prompt = "Selecionar pasta"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }

        persistBackupFolder(selectedURL)
        do {
            _ = try writeBackupFile()
            showSuccess(L.t("backup.status.folder_set"))
        } catch {
            showError(error.localizedDescription)
        }
    }

    func createManualBackup() {
        do {
            let fileURL = try writeBackupFile()
            showSuccess(String(format: L.t("backup.status.saved"), fileURL.lastPathComponent))
        } catch {
            showError(error.localizedDescription)
        }
    }

    func importBackupUsingPicker() {
        let panel = NSOpenPanel()
        panel.title = "Importar backup"
        panel.prompt = "Importar"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        let backupType = UTType(filenameExtension: UserDataBackupCodec.fileExtension)
        panel.allowedContentTypes = [backupType, .json].compactMap { $0 }

        guard panel.runModal() == .OK, let fileURL = panel.url else { return }

        do {
            let importedCount = try importBackup(from: fileURL)
            showSuccess(String(format: L.t("backup.status.imported"), importedCount))
        } catch {
            showError(error.localizedDescription)
        }
    }

    @discardableResult
    func importBackup(from fileURL: URL) throws -> Int {
        guard let data = try? Data(contentsOf: fileURL) else {
            throw BackupError.cannotReadBackup
        }
        let sessions = try UserDataBackupCodec.decodeSessions(from: data)
        store.save(sessions)
        NotificationCenter.default.post(name: .sessionsUpdated, object: nil)
        return sessions.count
    }

    // MARK: - Internal

    private func handleSessionsUpdated() {
        guard autoBackupEnabled else { return }
        do {
            _ = try writeBackupFile()
        } catch {
            showError(String(format: L.t("backup.status.auto_failed"), error.localizedDescription))
        }
    }

    @discardableResult
    private func writeBackupFile() throws -> URL {
        guard let folderURL = resolvedBackupFolderURL() else {
            throw BackupError.noBackupFolderSelected
        }

        return try withScopedFolderAccess(folderURL) {
            do {
                try FileManager.default.createDirectory(
                    at: folderURL,
                    withIntermediateDirectories: true
                )
            } catch {
                throw BackupError.cannotCreateBackupDirectory
            }

            let backupFileURL = folderURL.appendingPathComponent(UserDataBackupCodec.latestBackupFileName)
            do {
                let data = try UserDataBackupCodec.encode(sessions: store.loadAll())
                try data.write(to: backupFileURL, options: .atomic)
            } catch {
                throw BackupError.cannotWriteBackup
            }

            let now = Date()
            lastBackupAt = now
            defaults.set(now, forKey: lastBackupAtKey)
            return backupFileURL
        }
    }

    private func persistBackupFolder(_ folderURL: URL) {
        let normalizedURL = folderURL.standardizedFileURL
        backupFolderPath = normalizedURL.path
        defaults.set(normalizedURL.path, forKey: backupFolderPathKey)

        if let bookmarkData = try? normalizedURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            defaults.set(bookmarkData, forKey: backupFolderBookmarkKey)
        }
    }

    private func resolvedBackupFolderURL() -> URL? {
        if let bookmarkData = defaults.data(forKey: backupFolderBookmarkKey) {
            var isStale = false
            if let resolvedURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                if isStale {
                    persistBackupFolder(resolvedURL)
                } else if backupFolderPath != resolvedURL.path {
                    backupFolderPath = resolvedURL.path
                    defaults.set(resolvedURL.path, forKey: backupFolderPathKey)
                }
                return resolvedURL
            }
        }

        guard !backupFolderPath.isEmpty else { return nil }
        return URL(fileURLWithPath: backupFolderPath, isDirectory: true)
    }

    private func withScopedFolderAccess<T>(_ folderURL: URL, operation: () throws -> T) throws -> T {
        let accessGranted = folderURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }

    private func showSuccess(_ message: String) {
        statusMessage = message
        statusIsError = false
    }

    private func showError(_ message: String) {
        statusMessage = message
        statusIsError = true
    }
}
