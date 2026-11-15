import Foundation

struct DailyStreak: Equatable, Sendable {
    let days: Int
    let droppedToday: Bool

    static let none = DailyStreak(days: 0, droppedToday: false)

    var isAlive: Bool { days > 0 }
    var isWaitingOnToday: Bool { days > 0 && !droppedToday }

    static func run(of dates: [Date], now: Date, calendar: Calendar = .current) -> DailyStreak {
        let dayStarts = Set(dates.filter { $0 <= now }.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        let droppedToday = dayStarts.contains(today)
        guard var day = droppedToday ? today : calendar.date(byAdding: .day, value: -1, to: today),
              dayStarts.contains(day)
        else { return .none }
        var days = 0
        while dayStarts.contains(day) {
            days += 1
            guard let before = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = before
        }
        return DailyStreak(days: days, droppedToday: droppedToday)
    }

    static func week(of dates: [Date], now: Date, calendar: Calendar = .current) -> [Bool] {
        let dayStarts = Set(dates.filter { $0 <= now }.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        return (0..<7).reversed().map { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map(dayStarts.contains) ?? false
        }
    }
}

struct BoardStreaks: Equatable, Sendable {
    struct Entry: Sendable {
        let authorId: String
        let createdAt: Date
    }

    var mine: DailyStreak
    let crew: DailyStreak
    let members: [String: DailyStreak]
    let myWeek: [Bool]
    let crewWeek: [Bool]

    init(_ entries: [Entry], me: String, now: Date, calendar: Calendar = .current) {
        let mineDates = entries.filter { $0.authorId == me }.map(\.createdAt)
        let allDates = entries.map(\.createdAt)
        mine = DailyStreak.run(of: mineDates, now: now, calendar: calendar)
        crew = DailyStreak.run(of: allDates, now: now, calendar: calendar)
        myWeek = DailyStreak.week(of: mineDates, now: now, calendar: calendar)
        crewWeek = DailyStreak.week(of: allDates, now: now, calendar: calendar)
        members = Dictionary(grouping: entries, by: \.authorId)
            .mapValues { DailyStreak.run(of: $0.map(\.createdAt), now: now, calendar: calendar) }
    }

    init(drops: [Drop], me: String, now: Date, calendar: Calendar = .current) {
        self.init(drops.map { Entry(authorId: $0.authorId, createdAt: $0.createdAt) }, me: me, now: now, calendar: calendar)
    }

    static func now(clock: Date, drops: [Date], realNow: Date = .now) -> Date {
        max(clock, drops.filter { $0 <= realNow }.max() ?? clock)
    }

    var headline: String {
        switch (mine.days, mine.droppedToday) {
        case (0, _):
            return crew.isAlive && crew.days > 1
                ? "the crew is on a \(crew.days) day run. drop something today to join in."
                : "drop something today and you'll start a streak."
        case (1, true):
            return "you dropped something today, so your streak just started."
        case (let days, true):
            return "you've dropped something \(days) days in a row. nice."
        case (1, false):
            return "you dropped something yesterday. drop one today to keep it going."
        case (let days, false):
            return "your \(days) day streak is waiting on today's drop."
        }
    }
}
