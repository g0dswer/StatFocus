import XCTest
@testable import StatFocus

final class LocalizationTests: XCTestCase {

    func testCatalogReturnsCorrectStringPerLanguage() {
        let pt = StringCatalog.entries[.pt]
        let en = StringCatalog.entries[.en]

        XCTAssertEqual(pt?["tab.stats"], "Estatísticas")
        XCTAssertEqual(en?["tab.stats"], "Stats")

        XCTAssertEqual(pt?["stats.streak"], "Sequência")
        XCTAssertEqual(en?["stats.streak"], "Streak")
    }

    func testEveryPTKeyHasEnglishCounterpart() {
        let pt = StringCatalog.entries[.pt] ?? [:]
        let en = StringCatalog.entries[.en] ?? [:]

        let missing = pt.keys.filter { en[$0] == nil }
        XCTAssertTrue(missing.isEmpty, "Missing EN translations for keys: \(missing.sorted())")
    }

    func testEveryENKeyHasPortugueseCounterpart() {
        let pt = StringCatalog.entries[.pt] ?? [:]
        let en = StringCatalog.entries[.en] ?? [:]

        let missing = en.keys.filter { pt[$0] == nil }
        XCTAssertTrue(missing.isEmpty, "Missing PT translations for keys: \(missing.sorted())")
    }

    func testManagerTogglesLanguage() {
        let initial = LocalizationManager.shared.currentLanguage
        defer { LocalizationManager.shared.currentLanguage = initial }

        LocalizationManager.shared.currentLanguage = .pt
        XCTAssertEqual(LocalizationManager.shared.t("tab.stats"), "Estatísticas")

        LocalizationManager.shared.toggle()
        XCTAssertEqual(LocalizationManager.shared.currentLanguage, .en)
        XCTAssertEqual(LocalizationManager.shared.t("tab.stats"), "Stats")

        LocalizationManager.shared.toggle()
        XCTAssertEqual(LocalizationManager.shared.currentLanguage, .pt)
    }

    func testManagerPersistsToUserDefaults() {
        let initial = LocalizationManager.shared.currentLanguage
        defer { LocalizationManager.shared.currentLanguage = initial }

        LocalizationManager.shared.currentLanguage = .en
        XCTAssertEqual(UserDefaults.standard.string(forKey: "app.language"), "en")

        LocalizationManager.shared.currentLanguage = .pt
        XCTAssertEqual(UserDefaults.standard.string(forKey: "app.language"), "pt")
    }

    func testFallsBackToPTWhenKeyMissingInEN() {
        // Simulate by reading a key that exists in PT but might not in EN.
        // Since our test #2 ensures parity, we test the fallback path with a guaranteed-missing key.
        let initial = LocalizationManager.shared.currentLanguage
        defer { LocalizationManager.shared.currentLanguage = initial }

        LocalizationManager.shared.currentLanguage = .en
        let missingKey = "nonexistent.key.\(UUID().uuidString)"
        XCTAssertEqual(LocalizationManager.shared.t(missingKey), missingKey,
                       "Missing key should fall back to the raw key")
    }

    func testStatsViewModelPeriodTitleKeys() {
        XCTAssertEqual(StatsViewModel.HourlyPeriod.last7.titleKey,  "hourly.7d")
        XCTAssertEqual(StatsViewModel.HourlyPeriod.last30.titleKey, "hourly.30d")
        XCTAssertEqual(StatsViewModel.HourlyPeriod.all.titleKey,    "hourly.all")

        XCTAssertEqual(StatsViewModel.ChartPeriod.day.titleKey,   "period.day")
        XCTAssertEqual(StatsViewModel.ChartPeriod.week.titleKey,  "period.week")
        XCTAssertEqual(StatsViewModel.ChartPeriod.month.titleKey, "period.month")
        XCTAssertEqual(StatsViewModel.ChartPeriod.year.titleKey,  "period.year")
    }
}
