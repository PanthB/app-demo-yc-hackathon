import XCTest
@testable import AppDemo

final class TimeWordsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private var sundayMorning: Date { date(2026, 11, 15, 10) }

    private func parse(_ text: String, now: Date? = nil) -> ParsedTime? {
        TimeWords.parse(text, now: now ?? sundayMorning, calendar: calendar)
    }

    func testRelativeHourBecomesCountdownInNow() {
        let parsed = parse("remind me in 1 hr")
        XCTAssertEqual(parsed?.dueAt, sundayMorning.addingTimeInterval(3600))
        XCTAssertNil(parsed?.startsAt)
        XCTAssertEqual(parsed?.zone, .now)
        XCTAssertEqual(parsed?.whenLabel, "in 1 hr")
    }

    func testRelativeWordsAndUnits() {
        XCTAssertEqual(parse("call mom in 20 minutes")?.dueAt, sundayMorning.addingTimeInterval(1200))
        XCTAssertEqual(parse("in an hour")?.dueAt, sundayMorning.addingTimeInterval(3600))
        XCTAssertEqual(parse("in half an hour")?.dueAt, sundayMorning.addingTimeInterval(1800))
        XCTAssertEqual(parse("in 90min")?.dueAt, sundayMorning.addingTimeInterval(5400))
        XCTAssertEqual(parse("in two hours")?.dueAt, sundayMorning.addingTimeInterval(7200))
    }

    func testRelativeDaysLandInSomeday() {
        let parsed = parse("in 2 days")
        XCTAssertEqual(parsed?.dueAt, sundayMorning.addingTimeInterval(2 * 86400))
        XCTAssertEqual(parsed?.zone, .someday)
    }

    func testTonightDefaultsToSevenAndAcceptsBareHours() {
        let dinner = parse("dinner tonight")
        XCTAssertEqual(dinner?.startsAt, date(2026, 11, 15, 19))
        XCTAssertNil(dinner?.dueAt)
        XCTAssertEqual(dinner?.zone, .tonight)
        XCTAssertEqual(dinner?.whenLabel, "tonight")

        let late = parse("tonight at 8:30")
        XCTAssertEqual(late?.startsAt, date(2026, 11, 15, 20, 30))
        XCTAssertEqual(late?.whenLabel, "tonight at 8:30")
    }

    func testReminderAtClockTime() {
        let parsed = parse("remind me at 7pm")
        XCTAssertEqual(parsed?.dueAt, date(2026, 11, 15, 19))
        XCTAssertEqual(parsed?.zone, .tonight)
        XCTAssertEqual(parsed?.whenLabel, "at 7pm")
    }

    func testPastClockTimeRollsToTomorrow() {
        let parsed = parse("remind me at 9am")
        XCTAssertEqual(parsed?.dueAt, date(2026, 11, 16, 9))
        XCTAssertEqual(parsed?.whenLabel, "tomorrow at 9am")
    }

    func testWeekdaysAndWeekends() {
        let ramen = parse("ramen saturday")
        XCTAssertEqual(ramen?.startsAt, date(2026, 11, 21, 10))
        XCTAssertEqual(ramen?.zone, .thisWeekend)

        let weekend = parse("thrifting this weekend")
        XCTAssertEqual(weekend?.startsAt, date(2026, 11, 15, 10))
        XCTAssertEqual(weekend?.zone, .thisWeekend)

        let friday = parse("drinks friday night")
        XCTAssertEqual(friday?.startsAt, date(2026, 11, 20, 19))
        XCTAssertEqual(friday?.whenLabel, "friday night")
        XCTAssertEqual(friday?.zone, .someday)

        let nextWeekend = parse("hike next weekend")
        XCTAssertEqual(nextWeekend?.startsAt, date(2026, 11, 21, 10))
        XCTAssertEqual(nextWeekend?.zone, .someday)
    }

    func testWeekendFromAWeekday() {
        let wednesday = date(2026, 11, 18, 12)
        XCTAssertEqual(parse("this weekend", now: wednesday)?.startsAt, date(2026, 11, 21, 10))
        XCTAssertEqual(parse("next weekend", now: wednesday)?.startsAt, date(2026, 11, 28, 10))
    }

    func testTomorrow() {
        let parsed = parse("tomorrow at 6")
        XCTAssertEqual(parsed?.startsAt, date(2026, 11, 16, 18))
        XCTAssertEqual(parsed?.whenLabel, "tomorrow at 6")
    }

    func testMonths() {
        let concert = parse("this concert, sometime in march")
        XCTAssertEqual(concert?.startsAt, date(2027, 3, 1, 10))
        XCTAssertEqual(concert?.zone, .someday)
        XCTAssertEqual(concert?.whenLabel, "sometime in march")
    }

    func testTextWithoutTimeWords() {
        XCTAssertNil(parse("the ramen place on 5th"))
        XCTAssertNil(parse("for two hours"))
        XCTAssertNil(parse("in a while"))
    }
}
