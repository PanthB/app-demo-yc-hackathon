import Foundation

struct FeedGroup: Equatable, Identifiable, Sendable {
    var clusterId: String
    var clusterLabel: String
    var searching: Bool
    var suggestions: [FeedSuggestion]

    var id: String { clusterId }
}

extension FeedGroup: Decodable {
    private enum CodingKeys: String, CodingKey {
        case clusterId, clusterLabel, searching, suggestions
    }

    init(from decoder: Decoder) throws {
        let row = try decoder.container(keyedBy: CodingKeys.self)
        clusterId = try row.decode(String.self, forKey: .clusterId)
        clusterLabel = try row.decode(String.self, forKey: .clusterLabel)
        searching = (try? row.decode(Bool.self, forKey: .searching)) ?? false
        suggestions = (try? row.decode(LossyList<FeedSuggestion>.self, forKey: .suggestions))?.elements ?? []
    }
}

struct FeedSuggestion: Decodable, Equatable, Identifiable, Sendable {
    struct Source: Decodable, Equatable, Sendable {
        var clientId: String
        var title: String?
        var thumbnailUrl: String?
    }

    var id: String
    var kind: String
    var title: String
    var by: String?
    var when: String?
    var startsAt: Double?
    var place: String?
    var url: String
    var price: Double?
    var reason: String
    var description: String?
    var thumbnailUrl: String?
    var inspiredBy: [Source]?

    private enum CodingKeys: String, CodingKey {
        case id, kind, title, by, when, startsAt, url, price, reason, description, thumbnailUrl, inspiredBy
        case place = "where"
    }
}

extension FeedSuggestion {
    var isMedia: Bool {
        kind == "song" || kind == "watch"
    }

    var pill: (symbol: String, word: String) {
        if kind == "watch" { return ("film", "watch") }
        let known = DropKind(rawValue: kind).flatMap { [.event, .song, .place].contains($0) ? $0 : nil } ?? .link
        return (known.symbol, known.word)
    }

    var link: URL? {
        URL(string: url)
    }

    var site: String? {
        guard let host = link?.host()?.lowercased() else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var cost: String? {
        guard let price else { return nil }
        return price == 0 ? "free" : price.formatted(.currency(code: "USD").precision(.fractionLength(0...2)))
    }

    func starts(now: Date, calendar: Calendar = .current) -> String? {
        guard let startsAt else { return CardWords.clean(when) }
        let date = Date(timeIntervalSince1970: startsAt / 1000)
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        let clock = "\(hour % 12 == 0 ? 12 : hour % 12)\(minute == 0 ? "" : String(format: ":%02d", minute))\(hour < 12 ? "am" : "pm")"
        let day: String
        if calendar.isDate(date, inSameDayAs: now) {
            day = hour >= 17 ? "tonight" : "today"
        } else if calendar.isDateInTomorrow(date) {
            day = "tomorrow"
        } else if date > now, date.timeIntervalSince(now) < 6 * 86_400 {
            day = date.formatted(.dateTime.weekday(.wide)).lowercased()
        } else {
            day = date.formatted(.dateTime.month(.wide).day()).lowercased()
        }
        return "\(day) at \(clock)"
    }

    func meta(now: Date, calendar: Calendar = .current) -> String? {
        CardWords.meta([by, starts(now: now, calendar: calendar), place, cost], hiding: [title])
    }
}

#if DEBUG
extension FeedGroup {
    static func sample(for boardId: String, now: Date = .now) -> [FeedGroup] {
        guard boardId == SeedBoard.crewBoardId else { return [] }
        func drop(_ number: String, _ title: String) -> FeedSuggestion.Source {
            FeedSuggestion.Source(clientId: "5EED0002-0000-4000-8000-00000000000\(number)", title: title)
        }
        let park = drop("1", "dolores park on a sunny day")
        let bun = drop("2", "tartine morning bun")
        let song = drop("4", "san francisco (be sure to wear flowers in your hair)")
        let tour = drop("6", "mission district food tour")
        let chapel = drop("A", "the chapel")
        let saturday = now.addingTimeInterval(3 * 86_400).timeIntervalSince1970 * 1000
        return [
            FeedGroup(clusterId: "sunny-afternoons", clusterLabel: "upbeat, in the mission", searching: false, suggestions: [
                FeedSuggestion(
                    id: "sample-petty-theft", kind: "event", title: "petty theft", when: "november 28 at 9pm",
                    place: "the chapel, mission", url: "https://wl.eventim.us/event/Petty-Theft/705785?afflky=thechapel", price: 25,
                    reason: "because panth saved scott mckenzie.",
                    description: "sing along to tom petty classics at this all-ages mission show.",
                    inspiredBy: [song, park]
                ),
                FeedSuggestion(
                    id: "sample-bi-rite", kind: "place", title: "bi-rite creamery", place: "bi-rite creamery, mission",
                    url: "https://biritemarket.com/creamery/", reason: "because maya saved dolores park on a sunny day.",
                    description: "grab a scoop for a cheerful treat near dolores park.", inspiredBy: [park, bun]
                ),
                FeedSuggestion(
                    id: "sample-dock-of-the-bay", kind: "song", title: "(sittin' on) the dock of the bay", by: "otis redding",
                    url: "https://open.spotify.com/search/otis%20redding%20dock%20of%20the%20bay",
                    reason: "because panth saved scott mckenzie.", description: "a slow one for the walk home through the park.",
                    inspiredBy: [song]
                ),
            ]),
            FeedGroup(clusterId: "late-night", clusterLabel: "late night", searching: true, suggestions: [
                FeedSuggestion(
                    id: "sample-dj-phleck", kind: "event", title: "dj phleck", startsAt: saturday,
                    place: "casements bar, mission", url: "https://casementsbar.com/events", price: 0,
                    reason: "because alex saved mission district food tour.",
                    description: "a late-night mission dj set blending funk, disco, new wave, house, and italo.",
                    inspiredBy: [tour, chapel]
                ),
                FeedSuggestion(
                    id: "sample-last-black-man", kind: "watch", title: "the last black man in san francisco", by: "joe talbot",
                    url: "https://www.imdb.com/find/?q=the%20last%20black%20man%20in%20san%20francisco",
                    reason: "because sam saved the chapel.", description: "a quiet film about a house in the fillmore, for a night in.",
                    inspiredBy: [chapel]
                ),
            ]),
            FeedGroup(clusterId: "golden-hour", clusterLabel: "golden hour, by the water", searching: true, suggestions: []),
        ]
    }
}
#endif
