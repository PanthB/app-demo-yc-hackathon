import Foundation

enum ZoneClock {
    static let eveningHour = 17
    static let bucketHours = [0, 5, 12, 17, 22]
    static let soonWindow: TimeInterval = 90 * 60

    static func zone(
        stored: Zone,
        heldByPerson: Bool,
        startsAt: Date?,
        dueAt: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> Zone {
        guard !heldByPerson,
              let storedRank = Zone.timeOrder.firstIndex(of: stored),
              let timed = timeZone(for: dueAt ?? startsAt, now: now, calendar: calendar),
              let timedRank = Zone.timeOrder.firstIndex(of: timed),
              timedRank < storedRank
        else { return stored }
        return timed
    }

    static func timeZone(for date: Date?, now: Date, calendar: Calendar = .current) -> Zone? {
        guard let date else { return nil }
        if date.timeIntervalSince(now) <= soonWindow { return .now }
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
              let lateTonight = calendar.date(byAdding: .hour, value: 5, to: tomorrow)
        else { return nil }
        if date < tomorrow {
            return calendar.component(.hour, from: date) >= eveningHour ? .tonight : .now
        }
        if date < lateTonight { return .tonight }
        if let weekend = weekend(around: now, calendar: calendar), weekend.contains(date) {
            return .thisWeekend
        }
        return nil
    }

    static func weekend(around now: Date, calendar: Calendar = .current) -> Range<Date>? {
        let weekday = calendar.component(.weekday, from: now)
        let daysToMonday = (2 - weekday + 7) % 7 == 0 ? 7 : (2 - weekday + 7) % 7
        guard let end = calendar.date(byAdding: .day, value: daysToMonday, to: calendar.startOfDay(for: now)),
              let friday = calendar.date(byAdding: .day, value: -3, to: end),
              let start = calendar.date(bySettingHour: eveningHour, minute: 0, second: 0, of: friday)
        else { return nil }
        return start..<end
    }

    static func nextBoundary(after date: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: date)
        for dayOffset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            for hour in bucketHours {
                if let boundary = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day), boundary > date {
                    return boundary
                }
            }
        }
        return date.addingTimeInterval(3600)
    }
}
