import XCTest
@testable import StatFocus

final class TrialStateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Tests write to UserDefaults via TrialState.isPremium's didSet.
        // Wipe between tests so each starts from a known clean slate.
        UserDefaults.standard.removeObject(forKey: TrialState.premiumCacheKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: TrialState.premiumCacheKey)
        super.tearDown()
    }

    private func makeTrial(firstLaunch: Date, now: Date) -> TrialState {
        TrialState(firstLaunchProvider: { firstLaunch }, nowProvider: { now })
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = 12
        return Calendar.autoupdatingCurrent.date(from: c)!
    }

    func testFreshInstallHasFullTrialDays() {
        let first = date(year: 2026, month: 5, day: 21)
        let trial = makeTrial(firstLaunch: first, now: first)
        XCTAssertEqual(trial.daysRemaining, 7)
    }

    func testDaysRemainingDecreasesWithCalendarDays() {
        let first = date(year: 2026, month: 5, day: 21)
        // Day +3: 4 days remaining
        let now = date(year: 2026, month: 5, day: 24)
        let trial = makeTrial(firstLaunch: first, now: now)
        XCTAssertEqual(trial.daysRemaining, 4)
    }

    func testDaysRemainingClampsAtZero() {
        let first = date(year: 2026, month: 5, day: 21)
        let now = date(year: 2026, month: 6, day: 21)  // a month later
        let trial = makeTrial(firstLaunch: first, now: now)
        XCTAssertEqual(trial.daysRemaining, 0)
    }

    #if APP_STORE
    func testIsInTrialFalseWhenPremium() {
        let first = date(year: 2026, month: 5, day: 21)
        let trial = makeTrial(firstLaunch: first, now: first)
        XCTAssertTrue(trial.isInTrial)
        trial.isPremium = true
        XCTAssertFalse(trial.isInTrial)
        XCTAssertFalse(trial.isLocked)
    }

    func testIsLockedAfterTrialExpiryWithoutPremium() {
        let first = date(year: 2026, month: 5, day: 21)
        let now = date(year: 2026, month: 6, day: 21)
        let trial = makeTrial(firstLaunch: first, now: now)
        XCTAssertFalse(trial.isInTrial)
        XCTAssertTrue(trial.isLocked)
    }
    #else
    func testDevIDBuildIsAlwaysPremium() {
        let first = date(year: 2026, month: 5, day: 21)
        let now = date(year: 2026, month: 6, day: 21)
        let trial = makeTrial(firstLaunch: first, now: now)
        // In Dev ID build, isPremium defaults to true → never locked
        XCTAssertTrue(trial.isPremium)
        XCTAssertFalse(trial.isLocked)
        XCTAssertFalse(trial.isInTrial)
    }
    #endif
}
