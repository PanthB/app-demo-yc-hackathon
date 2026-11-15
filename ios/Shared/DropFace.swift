import Foundation

enum DropFace {
    static let noTime = "sometime"

    private static let stopWords: Set<String> = ["the", "a", "an", "at", "of", "and", "in", "on", "for", "to", "with", "from", "by"]
    private static let weekdayNames = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
    private static let monthNames = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    static func shortTitle(_ title: String?, maxWords: Int = 3) -> String? {
        guard let title else { return nil }
        var words = Array(title.lowercased().split(whereSeparator: \.isWhitespace).prefix(maxWords)).map(String.init)
        while let last = words.last, stopWords.contains(last) { words.removeLast() }
        return words.isEmpty ? nil : words.joined(separator: " ")
    }

    static func tag(dueAt: Date?, startsAt: Date?, whenLabel: String?, now: Date, calendar: Calendar = .current) -> String? {
        if let dueAt { return countdown(until: dueAt, now: now, calendar: calendar) }
        if let startsAt { return dateTag(startsAt, now: now, calendar: calendar) }
        return whenLabel
    }

    static func countdown(until date: Date, now: Date, calendar: Calendar = .current) -> String {
        let seconds = Int(date.timeIntervalSince(now).rounded(.up))
        if seconds <= 0 { return "now" }
        if seconds < 3600 { return String(format: "%d:%02d", seconds / 60, seconds % 60) }
        if seconds < 86400 { return "\(seconds / 3600)h \((seconds % 3600) / 60)m" }
        return dateTag(date, now: now, calendar: calendar)
    }

    static func dateTag(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let hasTime = calendar.component(.hour, from: date) != 0 || calendar.component(.minute, from: date) != 0
        let clock = hasTime ? clockText(date, calendar: calendar) : nil
        if calendar.isDate(date, inSameDayAs: now) { return clock ?? "today" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        if (0...6).contains(days) {
            let weekday = weekdayNames[calendar.component(.weekday, from: date) - 1]
            return clock.map { "\(weekday) \($0)" } ?? weekday
        }
        return "\(monthNames[calendar.component(.month, from: date) - 1]) \(calendar.component(.day, from: date))"
    }

    static func clockText(_ date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "am" : "pm"
        return minute == 0 ? "\(twelve)\(suffix)" : String(format: "%d:%02d%@", twelve, minute, suffix)
    }

    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func host(of url: String?) -> String? {
        guard let url, let host = URL(string: url)?.host() else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

extension Zone {
    var displayName: String {
        switch self {
        case .now: "now"
        case .tonight: "tonight"
        case .thisWeekend: "this weekend"
        case .someday: "someday"
        case .vibes: "vibes"
        case .done: "done"
        }
    }

    static let timeOrder: [Zone] = [.now, .tonight, .thisWeekend, .someday]
}
