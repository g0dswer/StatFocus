import XCTest
@testable import StatFocus

final class HourlyFocusTests: XCTestCase {
    private var tempDirectory: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StatFocusHourly-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        fileURL = tempDirectory.appendingPathComponent("sessions.json")
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    private func makeViewModel(with sessions: [StudySession]) -> StatsViewModel {
        let store = SessionStore(fileURL: fileURL)
        store.save(sessions)
        return StatsViewModel(store: store)
    }

    private func date(hour: Int, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 5
        comps.day = 7
        comps.hour = hour
        comps.minute = minute
        return Calendar.autoupdatingCurrent.date(from: comps)!
    }

    func testReturnsTwentyFourBuckets() {
        let vm = makeViewModel(with: [])
        let buckets = vm.hourlyFocusData()
        XCTAssertEqual(buckets.count, 24)
        XCTAssertEqual(buckets.map(\.hour), Array(0..<24))
        XCTAssertTrue(buckets.allSatisfy { $0.hours == 0 })
    }

    func testSessionContainedInSingleHourGoesEntirelyToThatHour() {
        let session = StudySession(startedAt: date(hour: 14, minute: 5), duration: 25 * 60, type: .focus)
        let vm = makeViewModel(with: [session])
        let buckets = vm.hourlyFocusData()

        XCTAssertEqual(buckets[14].hours, 25.0 / 60.0, accuracy: 0.0001)
        let othersTotal = buckets.enumerated()
            .filter { $0.offset != 14 }
            .reduce(0.0) { $0 + $1.element.hours }
        XCTAssertEqual(othersTotal, 0, accuracy: 0.0001)
    }

    func testSessionCrossingHourBoundaryIsDistributedProportionally() {
        // 14:50 + 25min => 10min in hour 14, 15min in hour 15
        let session = StudySession(startedAt: date(hour: 14, minute: 50), duration: 25 * 60, type: .focus)
        let vm = makeViewModel(with: [session])
        let buckets = vm.hourlyFocusData()

        XCTAssertEqual(buckets[14].hours, 10.0 / 60.0, accuracy: 0.0001)
        XCTAssertEqual(buckets[15].hours, 15.0 / 60.0, accuracy: 0.0001)
    }

    func testIgnoresNonFocusSessions() {
        let focus = StudySession(startedAt: date(hour: 9), duration: 30 * 60, type: .focus)
        let breakSession = StudySession(startedAt: date(hour: 10), duration: 30 * 60, type: .shortBreak)
        let vm = makeViewModel(with: [focus, breakSession])
        let buckets = vm.hourlyFocusData()

        XCTAssertEqual(buckets[9].hours, 0.5, accuracy: 0.0001)
        XCTAssertEqual(buckets[10].hours, 0, accuracy: 0.0001)
    }

    func testPeriodLast7FiltersOlderSessions() {
        let now = date(hour: 12)
        // Recent: 3 days ago at 09:00 → inside 7-day window
        let recent = StudySession(startedAt: date(hour: 9).adding(days: -3), duration: 30 * 60, type: .focus)
        // Old: 10 days ago at 18:00 → outside 7-day window
        let old = StudySession(startedAt: date(hour: 18).adding(days: -10), duration: 60 * 60, type: .focus)
        let vm = makeViewModel(with: [recent, old])

        let buckets = vm.hourlyFocusData(period: .last7, now: now)
        XCTAssertEqual(buckets[9].hours, 0.5, accuracy: 0.0001)
        XCTAssertEqual(buckets[18].hours, 0, accuracy: 0.0001)
    }

    func testPeriodLast30IncludesSessionsWithinWindow() {
        let now = date(hour: 12)
        // Inside: 20 days ago at 10:00
        let inside = StudySession(startedAt: date(hour: 10).adding(days: -20), duration: 60 * 60, type: .focus)
        // Outside: 45 days ago at 21:00
        let outside = StudySession(startedAt: date(hour: 21).adding(days: -45), duration: 60 * 60, type: .focus)
        let vm = makeViewModel(with: [inside, outside])

        let buckets = vm.hourlyFocusData(period: .last30, now: now)
        XCTAssertEqual(buckets[10].hours, 1.0, accuracy: 0.0001)
        XCTAssertEqual(buckets[21].hours, 0, accuracy: 0.0001)
    }

    func testPeriodAllMatchesUnfilteredCall() {
        let now = date(hour: 12)
        let sessions = [
            StudySession(startedAt: now.adding(days: -3), duration: 30 * 60, type: .focus),
            StudySession(startedAt: now.adding(days: -100), duration: 90 * 60, type: .focus),
        ]
        let vm = makeViewModel(with: sessions)

        let allViaParam = vm.hourlyFocusData(period: .all, now: now)
        let allViaDefault = vm.hourlyFocusData()
        XCTAssertEqual(allViaParam.map(\.hours), allViaDefault.map(\.hours))
    }

    func testTotalAcrossBucketsEqualsTotalFocusDuration() {
        let sessions = [
            StudySession(startedAt: date(hour: 8, minute: 30), duration: 50 * 60, type: .focus),
            StudySession(startedAt: date(hour: 14, minute: 45), duration: 90 * 60, type: .focus),
            StudySession(startedAt: date(hour: 23, minute: 50), duration: 30 * 60, type: .focus),
        ]
        let vm = makeViewModel(with: sessions)
        let total = vm.hourlyFocusData().reduce(0.0) { $0 + $1.hours }
        let expected = (50 + 90 + 30) / 60.0
        XCTAssertEqual(total, expected, accuracy: 0.001)
    }
}
