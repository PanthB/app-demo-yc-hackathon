import Foundation

struct ParsedTime: Equatable, Sendable {
    var dueAt: Date?
    var startsAt: Date?
    var zone: Zone
    var whenLabel: String
}

enum TimeWords {
    static func parse(_ text: String, now: Date = .now, calendar: Calendar = .current) -> ParsedTime? {
        let lower = text.lowercased()
        let isReminder = lower.contains("remind")

        if let relative = relativeDuration(in: lower) {
            let due = now.addingTimeInterval(relative.seconds)
            return ParsedTime(dueAt: due, zone: zone(for: due, now: now, calendar: calendar), whenLabel: relative.label)
        }

        let clock = clockTime(in: lower)
        let resolved: (date: Date, zone: Zone, label: String)

        if let anchor = dayAnchor(in: lower, now: now, calendar: calendar) {
            let date: Date
            if let clock {
                let hour = clock.hour(evening: anchor.isEvening)
                guard let set = calendar.date(bySettingHour: hour, minute: clock.minute, second: 0, of: anchor.day) else { return nil }
                date = set
            } else if let defaultHour = anchor.defaultHour {
                guard let set = calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: anchor.day) else { return nil }
                date = set
            } else {
                date = now
            }
            let label = clock.map { "\(anchor.label) \($0.label)" } ?? anchor.label
            resolved = (date, anchor.zone ?? zone(for: date, now: now, calendar: calendar), label)
        } else if let clock {
            guard var date = calendar.date(bySettingHour: clock.hour(evening: false), minute: clock.minute, second: 0, of: now) else { return nil }
            var label = clock.label
            if date <= now, let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) {
                date = tomorrow
                label = "tomorrow \(clock.label)"
            }
            resolved = (date, zone(for: date, now: now, calendar: calendar), label)
        } else if let month = monthMention(in: lower, now: now, calendar: calendar) {
            resolved = (month.date, .someday, month.label)
        } else {
            return nil
        }

        return ParsedTime(
            dueAt: isReminder ? resolved.date : nil,
            startsAt: isReminder ? nil : resolved.date,
            zone: resolved.zone,
            whenLabel: resolved.label
        )
    }

    static func zone(for date: Date, now: Date, calendar: Calendar) -> Zone {
        if date <= now.addingTimeInterval(3 * 3600) { return .now }
        if calendar.isDate(date, inSameDayAs: now) {
            return calendar.component(.hour, from: date) >= 17 ? .tonight : .now
        }
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 || weekday == 7, date < now.addingTimeInterval(7 * 86400) {
            return .thisWeekend
        }
        return .someday
    }

    private static let numberWords: [String: Double] = [
        "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
        "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12,
        "fifteen": 15, "twenty": 20, "thirty": 30, "forty": 40, "forty-five": 45,
    ]

    private static func relativeDuration(in text: String) -> (seconds: TimeInterval, label: String)? {
        let pattern = #"\bin\s+(half\s+an?\s+hour|(an?|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|fifteen|twenty|thirty|forty-five|forty|\d+(?:\.\d+)?)\s*(minutes?|mins?|m|hours?|hrs?|h|days?|d|weeks?|wks?|w))\b"#
        guard let groups = firstMatch(pattern, in: text), let whole = groups[0], let inner = groups[1] else { return nil }
        let label = whole.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if inner.hasPrefix("half") { return (1800, label) }
        guard let numberText = groups[2], let unit = groups[3]?.first,
              let number = numberWords[numberText] ?? Double(numberText)
        else { return nil }
        let unitSeconds: TimeInterval
        switch unit {
        case "m": unitSeconds = 60
        case "h": unitSeconds = 3600
        case "d": unitSeconds = 86400
        default: unitSeconds = 604800
        }
        return (number * unitSeconds, label)
    }

    private struct Clock {
        var hour: Int
        var minute: Int
        var meridiem: String?
        var label: String

        func hour(evening: Bool) -> Int {
            switch meridiem {
            case "am": return hour == 12 ? 0 : hour
            case "pm": return hour == 12 ? 12 : hour + 12
            default:
                if hour >= 12 { return hour }
                if evening || hour <= 7 { return hour + 12 }
                return hour
            }
        }
    }

    private static func clockTime(in text: String) -> Clock? {
        if let groups = firstMatch(#"\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b"#, in: text),
           let hour = groups[1].flatMap({ Int($0) }), (1...12).contains(hour) {
            let minute = groups[2].flatMap { Int($0) } ?? 0
            guard minute < 60, let meridiem = groups[3] else { return nil }
            let minuteText = groups[2].map { ":\($0)" } ?? ""
            return Clock(hour: hour, minute: minute, meridiem: meridiem, label: "at \(hour)\(minuteText)\(meridiem)")
        }
        if let groups = firstMatch(#"\bat\s+(\d{1,2})(?::(\d{2}))?\b"#, in: text),
           let hour = groups[1].flatMap({ Int($0) }), hour < 24 {
            let minute = groups[2].flatMap { Int($0) } ?? 0
            guard minute < 60 else { return nil }
            let minuteText = groups[2].map { ":\($0)" } ?? ""
            return Clock(hour: hour, minute: minute, meridiem: nil, label: "at \(hour)\(minuteText)")
        }
        return nil
    }

    private struct DayAnchor {
        var day: Date
        var label: String
        var zone: Zone?
        var defaultHour: Int?
        var isEvening: Bool
    }

    private static let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

    private static func dayAnchor(in text: String, now: Date, calendar: Calendar) -> DayAnchor? {
        let today = calendar.startOfDay(for: now)
        func addingDays(_ days: Int) -> Date { calendar.date(byAdding: .day, value: days, to: today) ?? today }
        func upcoming(weekday: Int) -> Date {
            let current = calendar.component(.weekday, from: today)
            return addingDays((weekday - current + 7) % 7)
        }
        let todayWeekday = calendar.component(.weekday, from: today)
        let thisWeekend = todayWeekday == 1 ? today : upcoming(weekday: 7)

        if firstMatch(#"\b(tonight|this evening)\b"#, in: text) != nil {
            return DayAnchor(day: today, label: "tonight", zone: .tonight, defaultHour: 19, isEvening: true)
        }
        if let groups = firstMatch(#"\b(tomorrow|tmrw|tmr)(\s+(night|evening))?\b"#, in: text) {
            let evening = groups[2] != nil
            return DayAnchor(day: addingDays(1), label: evening ? "tomorrow night" : "tomorrow", zone: nil, defaultHour: evening ? 19 : 9, isEvening: evening)
        }
        if firstMatch(#"\bnext\s+weekend\b"#, in: text) != nil {
            let saturday = calendar.date(byAdding: .day, value: todayWeekday == 1 ? 6 : 7, to: thisWeekend) ?? thisWeekend
            return DayAnchor(day: saturday, label: "next weekend", zone: .someday, defaultHour: 10, isEvening: false)
        }
        if firstMatch(#"\b(this|the)?\s*weekend\b"#, in: text) != nil {
            return DayAnchor(day: thisWeekend, label: "this weekend", zone: .thisWeekend, defaultHour: 10, isEvening: false)
        }
        if let groups = firstMatch(#"\b(?:(next|this|on)\s+)?(sunday|monday|tuesday|wednesday|thursday|friday|saturday)(\s+(night|evening))?\b"#, in: text),
           let name = groups[2], let index = weekdays.firstIndex(of: name) {
            let weekday = index + 1
            let day = upcoming(weekday: weekday)
            let evening = groups[3] != nil
            var label = name
            if let qualifier = groups[1], qualifier != "on" { label = "\(qualifier) \(name)" }
            if evening { label += " night" }
            let isWeekend = weekday == 1 || weekday == 7
            return DayAnchor(day: day, label: label, zone: isWeekend ? .thisWeekend : nil, defaultHour: evening ? 19 : 10, isEvening: evening)
        }
        if firstMatch(#"\btoday\b"#, in: text) != nil {
            return DayAnchor(day: today, label: "today", zone: nil, defaultHour: nil, isEvening: false)
        }
        if firstMatch(#"\bnext\s+week\b"#, in: text) != nil {
            return DayAnchor(day: addingDays((2 - todayWeekday + 7) % 7 == 0 ? 7 : (2 - todayWeekday + 7) % 7), label: "next week", zone: .someday, defaultHour: 9, isEvening: false)
        }
        return nil
    }

    private static let months = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]

    private static func monthMention(in text: String, now: Date, calendar: Calendar) -> (date: Date, label: String)? {
        let pattern = #"\b(?:(sometime|some time|early|late|mid)\s+)?in\s+(january|february|march|april|may|june|july|august|september|october|november|december)\b"#
        guard let groups = firstMatch(pattern, in: text), let name = groups[2], let index = months.firstIndex(of: name) else { return nil }
        let month = index + 1
        let currentMonth = calendar.component(.month, from: now)
        var year = calendar.component(.year, from: now)
        if month < currentMonth { year += 1 }
        let date: Date
        if month == currentMonth {
            date = now
        } else {
            guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1, hour: 10)) else { return nil }
            date = first
        }
        let qualifier = groups[1].map { $0 == "some time" ? "sometime" : $0 }
        return (date, qualifier.map { "\($0) in \(name)" } ?? "in \(name)")
    }

    private static func firstMatch(_ pattern: String, in text: String) -> [String?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }
        return (0..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) }
        }
    }
}
