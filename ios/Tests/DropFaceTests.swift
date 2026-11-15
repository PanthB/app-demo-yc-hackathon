import XCTest
@testable import AppDemo

final class DropFaceTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    func testADayWithNoTimeShowsTheDayAlone() {
        let sunday = date(15, 15)
        XCTAssertEqual(DropFace.dateTag(date(20, 0), now: sunday, calendar: calendar), "fri")
        XCTAssertEqual(DropFace.dateTag(date(15, 0), now: sunday, calendar: calendar), "today")
        XCTAssertEqual(DropFace.dateTag(date(29, 0), now: sunday, calendar: calendar), "nov 29")
        XCTAssertEqual(DropFace.tag(dueAt: nil, startsAt: date(21, 0), whenLabel: "this weekend", now: sunday, calendar: calendar), "sat")
    }

    func testATimedDayKeepsItsClock() {
        let sunday = date(15, 15)
        XCTAssertEqual(DropFace.dateTag(date(20, 19, 30), now: sunday, calendar: calendar), "fri 7:30pm")
        XCTAssertEqual(DropFace.dateTag(date(20, 0, 30), now: sunday, calendar: calendar), "fri 12:30am")
        XCTAssertEqual(DropFace.dateTag(date(15, 21), now: sunday, calendar: calendar), "9pm")
    }
}
