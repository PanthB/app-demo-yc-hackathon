import XCTest
@testable import AppDemo

final class ZoneClockTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    func testSoonIsNow() {
        let wednesday = date(18, 10)
        XCTAssertEqual(ZoneClock.timeZone(for: date(18, 11), now: wednesday, calendar: calendar), .now)
        XCTAssertEqual(ZoneClock.timeZone(for: date(18, 9), now: wednesday, calendar: calendar), .now)
    }

    func testLaterTodaySplitsAtEvening() {
        let wednesday = date(18, 10)
        XCTAssertEqual(ZoneClock.timeZone(for: date(18, 15), now: wednesday, calendar: calendar), .now)
        XCTAssertEqual(ZoneClock.timeZone(for: date(18, 19, 30), now: wednesday, calendar: calendar), .tonight)
        XCTAssertEqual(ZoneClock.timeZone(for: date(19, 1), now: wednesday, calendar: calendar), .tonight)
    }

    func testWeekendRunsFromFridayEveningToSundayNight() {
        let wednesday = date(18, 10)
        XCTAssertNil(ZoneClock.timeZone(for: date(20, 12), now: wednesday, calendar: calendar))
        XCTAssertEqual(ZoneClock.timeZone(for: date(20, 18), now: wednesday, calendar: calendar), .thisWeekend)
        XCTAssertEqual(ZoneClock.timeZone(for: date(21, 20), now: wednesday, calendar: calendar), .thisWeekend)
        XCTAssertEqual(ZoneClock.timeZone(for: date(22, 23), now: wednesday, calendar: calendar), .thisWeekend)
        XCTAssertNil(ZoneClock.timeZone(for: date(23, 10), now: wednesday, calendar: calendar))
    }

    func testOnSundayNextSaturdayIsNotThisWeekend() {
        let sunday = date(15, 11)
        XCTAssertNil(ZoneClock.timeZone(for: date(21, 20), now: sunday, calendar: calendar))
    }

    func testTimeOnlyMovesDropsTowardNow() {
        let thursday = date(19, 10)
        XCTAssertEqual(ZoneClock.zone(stored: .someday, heldByPerson: false, startsAt: date(21, 20), dueAt: nil, now: thursday, calendar: calendar), .thisWeekend)
        XCTAssertEqual(ZoneClock.zone(stored: .now, heldByPerson: false, startsAt: date(21, 20), dueAt: nil, now: thursday, calendar: calendar), .now)
        XCTAssertEqual(ZoneClock.zone(stored: .thisWeekend, heldByPerson: false, startsAt: date(21, 20), dueAt: nil, now: date(21, 19), calendar: calendar), .now)
        XCTAssertEqual(ZoneClock.zone(stored: .thisWeekend, heldByPerson: false, startsAt: date(17, 20), dueAt: nil, now: thursday, calendar: calendar), .now)
    }

    func testDueAtWinsOverStartsAt() {
        let thursday = date(19, 10)
        XCTAssertEqual(ZoneClock.zone(stored: .someday, heldByPerson: false, startsAt: date(21, 20), dueAt: date(19, 11), now: thursday, calendar: calendar), .now)
    }

    func testHandPlacedVibesAndDoneNeverMove() {
        let thursday = date(19, 10)
        XCTAssertEqual(ZoneClock.zone(stored: .someday, heldByPerson: true, startsAt: date(19, 10, 30), dueAt: nil, now: thursday, calendar: calendar), .someday)
        XCTAssertEqual(ZoneClock.zone(stored: .vibes, heldByPerson: false, startsAt: date(19, 10, 30), dueAt: nil, now: thursday, calendar: calendar), .vibes)
        XCTAssertEqual(ZoneClock.zone(stored: .done, heldByPerson: false, startsAt: date(19, 10, 30), dueAt: nil, now: thursday, calendar: calendar), .done)
    }

    func testNextBoundaryFollowsTheTimeOfDayBuckets() {
        XCTAssertEqual(ZoneClock.nextBoundary(after: date(19, 16, 30), calendar: calendar), date(19, 17))
        XCTAssertEqual(ZoneClock.nextBoundary(after: date(19, 17), calendar: calendar), date(19, 22))
        XCTAssertEqual(ZoneClock.nextBoundary(after: date(19, 23), calendar: calendar), date(20, 0))
    }
}
