import XCTest
@testable import AppDemo

final class NightStreakTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    func testNoDropsMeansNoStreak() {
        XCTAssertEqual(DailyStreak.run(of: [], now: at(15, 12), calendar: calendar), .none)
    }

    func testCountsConsecutiveDaysEndingToday() {
        let dates = [at(15, 9), at(14, 23), at(13, 8), at(13, 20), at(11, 10)]
        XCTAssertEqual(DailyStreak.run(of: dates, now: at(15, 12), calendar: calendar), DailyStreak(days: 3, droppedToday: true))
    }

    func testStaysAliveUntilTheEndOfTodayWhenTheLastDropWasYesterday() {
        let dates = [at(14, 22), at(13, 9), at(12, 18)]
        let lateToday = at(15, 23, 59)
        XCTAssertEqual(DailyStreak.run(of: dates, now: lateToday, calendar: calendar), DailyStreak(days: 3, droppedToday: false))
        XCTAssertTrue(DailyStreak.run(of: dates, now: lateToday, calendar: calendar).isWaitingOnToday)
    }

    func testBreaksAfterAWholeDayWithoutADrop() {
        let dates = [at(13, 22), at(12, 9)]
        XCTAssertEqual(DailyStreak.run(of: dates, now: at(15, 0, 5), calendar: calendar), .none)
    }

    func testUsesThePersonsOwnTimeZone() {
        let dates = [at(14, 23, 30), at(15, 0, 30)]
        XCTAssertEqual(DailyStreak.run(of: dates, now: at(15, 1), calendar: calendar).days, 2)
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        XCTAssertEqual(DailyStreak.run(of: dates, now: at(15, 1), calendar: tokyo).days, 1)
    }

    func testIgnoresDropsFromTheFuture() {
        XCTAssertEqual(DailyStreak.run(of: [at(16, 9)], now: at(15, 12), calendar: calendar), .none)
    }

    func testWeekEndsToday() {
        let week = DailyStreak.week(of: [at(15, 9), at(13, 9), at(9, 9), at(8, 9)], now: at(15, 12), calendar: calendar)
        XCTAssertEqual(week, [true, false, false, false, true, false, true])
    }

    func testBoardStreaksSplitMineTheCrewAndEachMember() {
        let entries = [
            BoardStreaks.Entry(authorId: "me", createdAt: at(14, 10)),
            BoardStreaks.Entry(authorId: "me", createdAt: at(13, 10)),
            BoardStreaks.Entry(authorId: "maya", createdAt: at(15, 8)),
            BoardStreaks.Entry(authorId: "maya", createdAt: at(12, 8)),
            BoardStreaks.Entry(authorId: "sam", createdAt: at(11, 8)),
        ]
        let streaks = BoardStreaks(entries, me: "me", now: at(15, 12), calendar: calendar)
        XCTAssertEqual(streaks.mine, DailyStreak(days: 2, droppedToday: false))
        XCTAssertEqual(streaks.crew, DailyStreak(days: 5, droppedToday: true))
        XCTAssertEqual(streaks.members["maya"], DailyStreak(days: 1, droppedToday: true))
        XCTAssertEqual(streaks.members["sam"], DailyStreak.none)
    }

    func testHeadlineTalksLikeAFriend() {
        func headline(_ mine: [Int], crew: [Int] = []) -> String {
            let entries = mine.map { BoardStreaks.Entry(authorId: "me", createdAt: at($0, 10)) }
                + crew.map { BoardStreaks.Entry(authorId: "maya", createdAt: at($0, 10)) }
            return BoardStreaks(entries, me: "me", now: at(15, 12), calendar: calendar).headline
        }
        XCTAssertEqual(headline([]), "drop something today and you'll start a streak.")
        XCTAssertEqual(headline([], crew: [15, 14, 13]), "the crew is on a 3 day run. drop something today to join in.")
        XCTAssertEqual(headline([15]), "you dropped something today, so your streak just started.")
        XCTAssertEqual(headline([15, 14, 13, 12]), "you've dropped something 4 days in a row. nice.")
        XCTAssertEqual(headline([14]), "you dropped something yesterday. drop one today to keep it going.")
        XCTAssertEqual(headline([14, 13]), "your 2 day streak is waiting on today's drop.")
        for words in [headline([]), headline([15]), headline([14, 13])] {
            XCTAssertEqual(words, words.lowercased())
        }
    }

    func testADropThatArrivesWhileTheAppIsOpenCountsRightAway() {
        let clock = at(15, 9)
        let arrived = at(15, 9, 5)
        let now = BoardStreaks.now(clock: clock, drops: [at(14, 20), arrived], realNow: at(15, 9, 6))
        XCTAssertEqual(now, arrived)
        let entries = [at(14, 20), arrived].map { BoardStreaks.Entry(authorId: "me", createdAt: $0) }
        XCTAssertEqual(BoardStreaks(entries, me: "me", now: now, calendar: calendar).mine, DailyStreak(days: 2, droppedToday: true))
        XCTAssertEqual(BoardStreaks(entries, me: "me", now: clock, calendar: calendar).mine, DailyStreak(days: 1, droppedToday: false))
    }

    func testADropDatedInTheFutureDoesNotMoveTheStreakClock() {
        let clock = at(15, 9)
        XCTAssertEqual(BoardStreaks.now(clock: clock, drops: [at(16, 10)], realNow: at(15, 9, 6)), clock)
        XCTAssertEqual(BoardStreaks.now(clock: clock, drops: [], realNow: at(15, 9, 6)), clock)
    }
}
