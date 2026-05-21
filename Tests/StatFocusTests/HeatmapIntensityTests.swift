import XCTest
@testable import StatFocus

final class HeatmapIntensityTests: XCTestCase {
    func testReturnsZeroForNonPositiveValues() {
        XCTAssertEqual(HeatmapIntensity.level(hours: 0), 0)
        XCTAssertEqual(HeatmapIntensity.level(hours: -1), 0)
    }

    func testMonotonicIntensityForIncreasingHours() {
        let values = stride(from: 0.0, through: 8.0, by: 0.5).map {
            HeatmapIntensity.level(hours: $0)
        }

        for index in 1..<values.count {
            XCTAssertGreaterThanOrEqual(values[index], values[index - 1])
        }
    }

    func testUsesFixedThresholds() {
        XCTAssertEqual(HeatmapIntensity.level(hours: 0.3), 1)
        XCTAssertEqual(HeatmapIntensity.level(hours: 0.99), 1)
        XCTAssertEqual(HeatmapIntensity.level(hours: 1.0), 2)
        XCTAssertEqual(HeatmapIntensity.level(hours: 1.99), 2)
        XCTAssertEqual(HeatmapIntensity.level(hours: 2.0), 3)
        XCTAssertEqual(HeatmapIntensity.level(hours: 3.99), 3)
        XCTAssertEqual(HeatmapIntensity.level(hours: 4.0), 4)
        XCTAssertEqual(HeatmapIntensity.level(hours: 80), 4)
    }
}
