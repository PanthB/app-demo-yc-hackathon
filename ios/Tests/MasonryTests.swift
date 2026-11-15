import XCTest
@testable import AppDemo

final class MasonryTests: XCTestCase {
    func testColumnsShareTheWidthMinusTheGutters() {
        XCTAssertEqual(Masonry.columnWidth(total: 370, columns: 2, spacing: 12), 179)
        XCTAssertEqual(Masonry.columnWidth(total: 10, columns: 2, spacing: 12), 0)
        XCTAssertEqual(Masonry.columnWidth(total: 370, columns: 0, spacing: 12), 0)
    }

    func testEachCardGoesToTheShorterColumnAndTiesGoLeft() {
        let result = Masonry.place(heights: [100, 60, 80, 40], columns: 2, spacing: 12)
        XCTAssertEqual(result.placements, [
            Masonry.Placement(column: 0, y: 0),
            Masonry.Placement(column: 1, y: 0),
            Masonry.Placement(column: 1, y: 72),
            Masonry.Placement(column: 0, y: 112),
        ])
        XCTAssertEqual(result.height, 152)
    }

    func testATallLastCardGetsAColumnToItself() {
        let result = Masonry.place(heights: [240, 205, 445], columns: 2, spacing: 12)
        XCTAssertEqual(result.placements, [
            Masonry.Placement(column: 0, y: 0),
            Masonry.Placement(column: 0, y: 252),
            Masonry.Placement(column: 1, y: 0),
        ])
        XCTAssertEqual(result.height, 457)
    }

    func testTheFirstCardStaysInTheLeadingColumn() {
        for heights in [[300, 100, 100, 100], [50, 400, 60, 70, 300], [120, 120, 120]] as [[CGFloat]] {
            XCTAssertEqual(Masonry.place(heights: heights, columns: 2, spacing: 12).placements.first, Masonry.Placement(column: 0, y: 0))
        }
    }

    func testALongSectionStillPlacesEveryCard() {
        let heights = (0..<30).map { CGFloat(100 + ($0 * 37) % 160) }
        let result = Masonry.place(heights: heights, columns: 2, spacing: 12)
        XCTAssertEqual(result.placements.count, 30)
        XCTAssertGreaterThan(result.height, heights.reduce(0, +) / 2)
    }

    func testAnEmptyGridHasNoHeight() {
        let result = Masonry.place(heights: [], columns: 2, spacing: 12)
        XCTAssertTrue(result.placements.isEmpty)
        XCTAssertEqual(result.height, 0)
    }

    func testOneCardIsAsTallAsItself() {
        XCTAssertEqual(Masonry.place(heights: [90], columns: 2, spacing: 12).height, 90)
    }
}
