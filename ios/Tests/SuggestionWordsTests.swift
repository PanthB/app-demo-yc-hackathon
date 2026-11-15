import XCTest
@testable import AppDemo

final class SuggestionWordsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    private func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func suggestion(kind: String = "event", title: String = "petty theft", when: String? = nil, startsAt: Date? = nil, place: String? = nil, price: Double? = nil, description: String? = nil) -> FeedSuggestion {
        FeedSuggestion(
            id: "one", kind: kind, title: title, when: when, startsAt: startsAt.map { $0.timeIntervalSince1970 * 1000 },
            place: place, url: "https://www.example.com/page", price: price, reason: "because maya saved otis redding.", description: description
        )
    }

    func testTheStartIsSaidFromItsTimeNotFromTheBackendsWords() {
        let now = at(2026, 11, 15, 14)
        XCTAssertEqual(suggestion(when: "in 2 hr", startsAt: at(2026, 11, 15, 16)).starts(now: now, calendar: calendar), "today at 4pm")
        XCTAssertEqual(suggestion(startsAt: at(2026, 11, 15, 21, 30)).starts(now: now, calendar: calendar), "tonight at 9:30pm")
        XCTAssertEqual(suggestion(startsAt: at(2026, 11, 16, 0)).starts(now: now, calendar: calendar), "tomorrow at 12am")
        XCTAssertEqual(suggestion(startsAt: at(2026, 11, 21, 22)).starts(now: now, calendar: calendar), "saturday at 10pm")
        XCTAssertEqual(suggestion(startsAt: at(2026, 11, 28, 21)).starts(now: now, calendar: calendar), "november 28 at 9pm")
        XCTAssertEqual(suggestion(when: "Saturday at 8pm").starts(now: now, calendar: calendar), "saturday at 8pm")
        XCTAssertNil(suggestion().starts(now: now, calendar: calendar))
    }

    func testThePriceIsFreeWholeDollarsOrDollarsAndCents() {
        XCTAssertEqual(suggestion(price: 0).cost, "free")
        XCTAssertEqual(suggestion(price: 25).cost, "$25")
        XCTAssertEqual(suggestion(price: 12.5).cost, "$12.50")
        XCTAssertNil(suggestion().cost)
    }

    func testAPlaceThatRepeatsTheTitleIsCutToItsNeighborhood() {
        XCTAssertEqual(suggestion(kind: "place", title: "pacific overlook", place: "pacific overlook, presidio").spot, "presidio")
        XCTAssertEqual(suggestion(place: "the chapel, mission").spot, "the chapel, mission")
        XCTAssertNil(suggestion(place: "  ").spot)
    }

    func testACitationIsTakenOutOfTheDescription() {
        let cited = "a coastal perch for sunset and golden gate views. ([presidio.gov](https://presidio.gov/explore/attractions/pacific-overlook?utm_source=openai))"
        XCTAssertEqual(suggestion(description: cited).blurb, "a coastal perch for sunset and golden gate views.")
        XCTAssertEqual(suggestion(description: "sing along to tom petty classics.").blurb, "sing along to tom petty classics.")
        XCTAssertNil(suggestion(description: "([presidio.gov](https://presidio.gov))").blurb)
    }

    func testTheMetaLineIsWhoWhenWhereAndPrice() {
        let now = at(2026, 11, 15, 14)
        let event = suggestion(startsAt: at(2026, 11, 28, 21), place: "the chapel, mission", price: 25)
        XCTAssertEqual(event.meta(now: now, calendar: calendar), "november 28 at 9pm · the chapel, mission · $25")
        XCTAssertNil(suggestion(kind: "place", title: "bi-rite creamery", place: "bi-rite creamery").meta(now: now, calendar: calendar))
    }

    func testEveryKindHasAPillAndASide() {
        XCTAssertEqual(suggestion(kind: "event").pill.word, "event")
        XCTAssertEqual(suggestion(kind: "song").pill.word, "song")
        XCTAssertEqual(suggestion(kind: "place").pill.word, "place")
        XCTAssertEqual(suggestion(kind: "watch").pill.word, "watch")
        XCTAssertEqual(suggestion(kind: "something new").pill.word, "link")
        XCTAssertTrue(suggestion(kind: "song").isMedia)
        XCTAssertTrue(suggestion(kind: "watch").isMedia)
        XCTAssertFalse(suggestion(kind: "event").isMedia)
        XCTAssertEqual(suggestion().site, "example.com")
    }

    private func group(_ id: String, searching: Bool) -> FeedGroup {
        FeedGroup(clusterId: id, clusterLabel: id, searching: searching, suggestions: [])
    }

    func testARefreshShowsEveryGroupLookingUntilTheBackendAnswersOrNinetySecondsPass() {
        let start = at(2026, 11, 15, 15)
        var lines = SearchLines()
        lines.ask(for: ["a", "b", "c"], now: start)
        XCTAssertTrue(lines.isAsking(now: start.addingTimeInterval(5)))
        lines.take([group("a", searching: false), group("b", searching: false), group("c", searching: false)], now: start.addingTimeInterval(1))
        XCTAssertTrue(lines.shows("a", now: start.addingTimeInterval(2)))
        XCTAssertTrue(lines.shows("c", now: start.addingTimeInterval(89)))
        XCTAssertFalse(lines.shows("c", now: start.addingTimeInterval(91)))
        XCTAssertFalse(lines.isAsking(now: start.addingTimeInterval(91)))
        XCTAssertEqual(lines.next(after: start), start.addingTimeInterval(90))
        XCTAssertNil(lines.next(after: start.addingTimeInterval(91)))
    }

    func testOnceTheBackendSaysWhichGroupsItSearchesOnlyThoseKeepTheLine() {
        let start = at(2026, 11, 15, 15)
        var lines = SearchLines()
        lines.ask(for: ["a", "b", "c"], now: start)
        lines.take([group("a", searching: true), group("b", searching: true), group("c", searching: false)], now: start.addingTimeInterval(1))
        XCTAssertTrue(lines.shows("a", now: start.addingTimeInterval(2)))
        XCTAssertFalse(lines.shows("c", now: start.addingTimeInterval(2)))
        lines.take([group("a", searching: false), group("b", searching: true), group("c", searching: false)], now: start.addingTimeInterval(20))
        XCTAssertFalse(lines.shows("a", now: start.addingTimeInterval(21)))
        XCTAssertTrue(lines.shows("b", now: start.addingTimeInterval(21)))
        XCTAssertTrue(lines.isAsking(now: start.addingTimeInterval(21)))
        lines.take([group("a", searching: false), group("b", searching: false), group("c", searching: false)], now: start.addingTimeInterval(40))
        XCTAssertFalse(lines.shows("b", now: start.addingTimeInterval(41)))
        XCTAssertFalse(lines.isAsking(now: start.addingTimeInterval(41)))
    }

    func testASearchTheBackendNeverFinishesStopsShowingAfterNinetySeconds() {
        let start = at(2026, 11, 15, 15)
        var lines = SearchLines()
        lines.take([group("a", searching: true)], now: start)
        XCTAssertTrue(lines.shows("a", now: start.addingTimeInterval(60)))
        lines.take([group("a", searching: true)], now: start.addingTimeInterval(120))
        XCTAssertFalse(lines.shows("a", now: start.addingTimeInterval(121)))
        lines.take([group("a", searching: false)], now: start.addingTimeInterval(130))
        lines.take([group("a", searching: true)], now: start.addingTimeInterval(140))
        XCTAssertTrue(lines.shows("a", now: start.addingTimeInterval(141)))
    }

    func testARefreshTheBackendTurnsDownKeepsOnlyWhatItIsAlreadySearching() {
        let start = at(2026, 11, 15, 15)
        var lines = SearchLines()
        lines.take([group("a", searching: true), group("b", searching: false)], now: start)
        lines.ask(for: ["a", "b"], now: start.addingTimeInterval(10))
        lines.giveUp([group("a", searching: true), group("b", searching: false)], now: start.addingTimeInterval(11))
        XCTAssertFalse(lines.isAsking(now: start.addingTimeInterval(12)))
        XCTAssertTrue(lines.shows("a", now: start.addingTimeInterval(12)))
        XCTAssertFalse(lines.shows("b", now: start.addingTimeInterval(12)))
    }

    func testAGroupReadsWhatTheBackendSendsAndSkipsWhatItCant() throws {
        let json = """
        [{"clusterId":"late-night","clusterLabel":"late night","searching":true,"suggestions":[
          {"id":"a","kind":"event","title":"dj phleck","url":"https://casementsbar.com/events","reason":"because alex saved the chapel.","where":"casements bar, mission","startsAt":1795327200000,"price":0,"foundAt":1794779416793,"inspiredBy":[{"clientId":"5EED0002-0000-4000-8000-00000000000A","title":"the chapel"}]},
          {"id":"b","kind":"song"},
          {"id":"c","kind":"song","title":"the dock of the bay","by":"otis redding","url":"https://open.spotify.com/track/1","reason":"because panth saved scott mckenzie.","inspiredBy":[],"foundAt":1}
        ]}]
        """
        let groups = try JSONDecoder().decode(LossyList<FeedGroup>.self, from: Data(json.utf8)).elements
        XCTAssertEqual(groups.count, 1)
        XCTAssertTrue(groups[0].searching)
        XCTAssertEqual(groups[0].suggestions.map(\.id), ["a", "c"])
        XCTAssertEqual(groups[0].suggestions[0].place, "casements bar, mission")
        XCTAssertEqual(groups[0].suggestions[0].inspiredBy?.first?.title, "the chapel")
        XCTAssertEqual(groups[0].suggestions[1].by, "otis redding")
    }
}
