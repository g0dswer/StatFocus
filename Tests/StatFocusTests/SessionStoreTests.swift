import XCTest
@testable import StatFocus

final class SessionStoreTests: XCTestCase {
    private var tempDirectory: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StatFocusTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        fileURL = tempDirectory.appendingPathComponent("sessions.json")
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testInsertLoadAndDeleteAll() {
        let store = SessionStore(fileURL: fileURL)
        XCTAssertTrue(store.loadAll().isEmpty)

        let first = StudySession(startedAt: Date(timeIntervalSince1970: 1_700_000_000), duration: 1_500, type: .focus)
        let second = StudySession(startedAt: Date(timeIntervalSince1970: 1_700_003_600), duration: 300, type: .shortBreak)

        store.insert(first)
        store.insert(second)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].type, .focus)
        XCTAssertEqual(loaded[1].type, .shortBreak)
        XCTAssertEqual(loaded[0].duration, 1_500)
        XCTAssertEqual(loaded[1].duration, 300)

        store.deleteAll()
        XCTAssertTrue(store.loadAll().isEmpty)
    }

    func testPersistsAcrossStoreInstancesUsingSameFile() {
        let writer = SessionStore(fileURL: fileURL)
        writer.save([
            StudySession(startedAt: Date(timeIntervalSince1970: 1_700_100_000), duration: 900, type: .focus)
        ])

        let reader = SessionStore(fileURL: fileURL)
        let loaded = reader.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].type, .focus)
        XCTAssertEqual(loaded[0].duration, 900)
        XCTAssertEqual(loaded[0].startedAt.timeIntervalSince1970, 1_700_100_000, accuracy: 1.0)
    }

    func testBackupCodecRoundTripPayload() throws {
        let sessions = [
            StudySession(startedAt: Date(timeIntervalSince1970: 1_701_000_000), duration: 1_500, type: .focus),
            StudySession(startedAt: Date(timeIntervalSince1970: 1_701_003_600), duration: 300, type: .shortBreak)
        ]

        let data = try UserDataBackupCodec.encode(sessions: sessions, exportedAt: Date(timeIntervalSince1970: 1_701_100_000))
        let decoded = try UserDataBackupCodec.decodeSessions(from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].type, .focus)
        XCTAssertEqual(decoded[1].type, .shortBreak)
        XCTAssertEqual(decoded[0].duration, 1_500)
        XCTAssertEqual(decoded[1].duration, 300)
    }

    func testBackupCodecReadsLegacyArrayFormat() throws {
        let original = [
            StudySession(startedAt: Date(timeIntervalSince1970: 1_702_000_000), duration: 2_400, type: .focus)
        ]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let legacyData = try encoder.encode(original)

        let decoded = try UserDataBackupCodec.decodeSessions(from: legacyData)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].type, .focus)
        XCTAssertEqual(decoded[0].duration, 2_400)
    }
}
