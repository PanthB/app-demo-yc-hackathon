import Foundation

enum GlassCopy {
    enum FrontLabel: Equatable {
        case countdown(Date)
        case time(String)
        case phrase(String)
    }

    static let emptyBoard = "nothing here yet. share anything from any app and it'll show up."
    static let emptyDone = "nothing's done yet. drag something here once you've done it."

    private static let weekdays = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
    private static let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    static func zoneLabel(_ zone: Zone) -> String {
        switch zone {
        case .now: "now"
        case .tonight: "tonight"
        case .thisWeekend: "this weekend"
        case .someday: "someday"
        case .vibes: "vibes"
        case .done: "done"
        }
    }

    static func clock(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "am" : "pm"
        if minute == 0 { return "\(hour12)\(suffix)" }
        return "\(hour12):\(minute < 10 ? "0" : "")\(minute)\(suffix)"
    }

    static func when(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let time = clock(date, calendar: calendar)
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        switch days {
        case 0:
            return calendar.component(.hour, from: date) >= 17 ? "tonight \(time)" : "today \(time)"
        case 1:
            return "tomorrow \(time)"
        case 2...6:
            return "\(weekdays[(calendar.component(.weekday, from: date) + 6) % 7]) \(time)"
        default:
            return "\(months[(calendar.component(.month, from: date) + 11) % 12]) \(calendar.component(.day, from: date))"
        }
    }

    static func countdown(to due: Date, now: Date, calendar: Calendar = .current) -> String {
        let remaining = Int(due.timeIntervalSince(now))
        if remaining <= 0 { return "now" }
        if remaining < 3600 {
            let seconds = remaining % 60
            return "\(remaining / 60):\(seconds < 10 ? "0" : "")\(seconds)"
        }
        if remaining < 86400 {
            return "\(remaining / 3600)h \((remaining % 3600) / 60)m"
        }
        return when(due, now: now, calendar: calendar)
    }

    static func frontLabel(
        dueAt: Date?,
        startsAt: Date?,
        whenLabel: String?,
        now: Date,
        calendar: Calendar = .current
    ) -> FrontLabel? {
        if let dueAt {
            let remaining = dueAt.timeIntervalSince(now)
            if remaining > 0, remaining < 3600 { return .countdown(dueAt) }
            return .time(countdown(to: dueAt, now: now, calendar: calendar))
        }
        let phrase = whenLabel?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let startsAt {
            let ahead = startsAt.timeIntervalSince(now)
            if ahead > -86400, ahead < 7 * 86400 {
                return .time(when(startsAt, now: now, calendar: calendar))
            }
            if let phrase, !phrase.isEmpty { return .phrase(phrase) }
            return .time(when(startsAt, now: now, calendar: calendar))
        }
        if let phrase, !phrase.isEmpty { return .phrase(phrase) }
        return nil
    }

    static func spoken(_ label: FrontLabel?, now: Date, calendar: Calendar = .current) -> String? {
        switch label {
        case .countdown(let due): countdown(to: due, now: now, calendar: calendar)
        case .time(let text), .phrase(let text): text
        case nil: nil
        }
    }

    static func shortTitle(_ title: String?, limit: Int = 3) -> String? {
        guard let title else { return nil }
        let words = title.lowercased().split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return nil }
        return words.prefix(limit).joined(separator: " ")
    }

    static func host(_ url: String?) -> String? {
        guard let url, let host = URLComponents(string: url)?.host?.lowercased(), !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    static func rawSummary(text: String?, url: String?) -> String {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if !trimmed.isEmpty { return trimmed }
        return host(url) ?? "something you dropped"
    }

    static func kindName(_ kind: ObjectKind, isReminder: Bool) -> String {
        switch kind {
        case .cutout: "cutout"
        case .polaroid: "photo"
        case .record: "record"
        case .slip: "voice note"
        case .sticky: isReminder ? "reminder" : "note"
        case .stub: "ticket"
        case .postcard: "postcard"
        }
    }
}
