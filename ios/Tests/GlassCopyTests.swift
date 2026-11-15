import XCTest
@testable import AppDemo

final class GlassCopyTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private var sundayMorning: Date { date(2026, 11, 15, 10) }

    func testClockIsShortAndLowercase() {
        XCTAssertEqual(GlassCopy.clock(date(2026, 11, 15, 20), calendar: calendar), "8pm")
        XCTAssertEqual(GlassCopy.clock(date(2026, 11, 15, 9, 5), calendar: calendar), "9:05am")
        XCTAssertEqual(GlassCopy.clock(date(2026, 11, 15, 0), calendar: calendar), "12am")
        XCTAssertEqual(GlassCopy.clock(date(2026, 11, 15, 12, 30), calendar: calendar), "12:30pm")
    }

    func testWhenNamesTheDayTheWayAFriendWould() {
        XCTAssertEqual(GlassCopy.when(date(2026, 11, 15, 15), now: sundayMorning, calendar: calendar), "today 3pm")
        XCTAssertEqual(GlassCopy.when(date(2026, 11, 15, 20), now: sundayMorning, calendar: calendar), "tonight 8pm")
        XCTAssertEqual(GlassCopy.when(date(2026, 11, 16, 9), now: sundayMorning, calendar: calendar), "tomorrow 9am")
        XCTAssertEqual(GlassCopy.when(date(2026, 11, 21, 20), now: sundayMorning, calendar: calendar), "sat 8pm")
        XCTAssertEqual(GlassCopy.when(date(2027, 3, 4, 20), now: sundayMorning, calendar: calendar), "mar 4")
    }

    func testCountdownFormats() {
        XCTAssertEqual(GlassCopy.countdown(to: sundayMorning.addingTimeInterval(3134), now: sundayMorning, calendar: calendar), "52:14")
        XCTAssertEqual(GlassCopy.countdown(to: sundayMorning.addingTimeInterval(65), now: sundayMorning, calendar: calendar), "1:05")
        XCTAssertEqual(GlassCopy.countdown(to: sundayMorning.addingTimeInterval(2 * 3600 + 14 * 60), now: sundayMorning, calendar: calendar), "2h 14m")
        XCTAssertEqual(GlassCopy.countdown(to: sundayMorning.addingTimeInterval(-5), now: sundayMorning, calendar: calendar), "now")
        XCTAssertEqual(GlassCopy.countdown(to: date(2026, 11, 21, 20), now: sundayMorning, calendar: calendar), "sat 8pm")
    }

    func testFrontLabelPrefersACountdownThenANearDateThenThePhrase() {
        let due = sundayMorning.addingTimeInterval(1800)
        XCTAssertEqual(
            GlassCopy.frontLabel(dueAt: due, startsAt: nil, whenLabel: "in 30 min", now: sundayMorning, calendar: calendar),
            .countdown(due)
        )
        XCTAssertEqual(
            GlassCopy.frontLabel(dueAt: nil, startsAt: date(2026, 11, 21, 20), whenLabel: "Saturday night", now: sundayMorning, calendar: calendar),
            .time("sat 8pm")
        )
        XCTAssertEqual(
            GlassCopy.frontLabel(dueAt: nil, startsAt: date(2027, 3, 1, 12), whenLabel: "Sometime in March", now: sundayMorning, calendar: calendar),
            .phrase("sometime in march")
        )
        XCTAssertEqual(
            GlassCopy.frontLabel(dueAt: nil, startsAt: nil, whenLabel: "some weeknight", now: sundayMorning, calendar: calendar),
            .phrase("some weeknight")
        )
        XCTAssertNil(GlassCopy.frontLabel(dueAt: nil, startsAt: nil, whenLabel: " ", now: sundayMorning, calendar: calendar))
    }

    func testShortTitleKeepsThreeLowercaseWords() {
        XCTAssertEqual(GlassCopy.shortTitle("Mk.gee at The Fillmore tonight"), "mk.gee at the")
        XCTAssertEqual(GlassCopy.shortTitle("Ramen"), "ramen")
        XCTAssertNil(GlassCopy.shortTitle("   "))
        XCTAssertNil(GlassCopy.shortTitle(nil))
    }

    func testRawSummaryFallsBackToTheLinkHost() {
        XCTAssertEqual(GlassCopy.rawSummary(text: " Call Mom ", url: nil), "call mom")
        XCTAssertEqual(GlassCopy.rawSummary(text: nil, url: "https://www.tiktok.com/@eats/video/1"), "tiktok.com")
        XCTAssertEqual(GlassCopy.rawSummary(text: "", url: nil), "something you dropped")
    }

    func testEveryLineTheAppSaysIsLowercase() {
        for line in [GlassCopy.emptyBoard, GlassCopy.emptyDone] + Zone.allCases.map(GlassCopy.zoneLabel) {
            XCTAssertEqual(line, line.lowercased())
        }
    }
}
