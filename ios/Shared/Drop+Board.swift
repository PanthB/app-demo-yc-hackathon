import Foundation

extension Drop {
    var isArriving: Bool {
        status == .pending && !zoneSetByUser
    }

    var showsRawThing: Bool {
        status != .processed && !zoneSetByUser
    }

    var sortDate: Date {
        dueAt ?? startsAt ?? createdAt
    }

    var frontTitle: String? {
        DropFace.shortTitle(title)
    }

    var linkHost: String? {
        DropFace.host(of: url)
    }

    func boardZone(now: Date, calendar: Calendar = .current) -> Zone {
        ZoneClock.zone(
            stored: zone,
            heldByPerson: zoneSetByUser,
            startsAt: startsAt,
            dueAt: dueAt,
            now: now,
            calendar: calendar
        )
    }

    func tag(now: Date, calendar: Calendar = .current) -> String? {
        DropFace.tag(dueAt: dueAt, startsAt: startsAt, whenLabel: whenLabel, now: now, calendar: calendar)
    }

    func frontTag(now: Date, calendar: Calendar = .current) -> String {
        tag(now: now, calendar: calendar) ?? DropFace.noTime
    }
}

struct BoardContents {
    private(set) var arriving: [Drop] = []
    private var byZone: [Zone: [Drop]] = [:]

    init(_ drops: [Drop], now: Date, calendar: Calendar = .current) {
        for drop in drops {
            if drop.isArriving {
                arriving.append(drop)
            } else {
                byZone[drop.boardZone(now: now, calendar: calendar), default: []].append(drop)
            }
        }
        arriving.sort { $0.createdAt > $1.createdAt }
        for zone in byZone.keys {
            byZone[zone]?.sort { $0.sortDate < $1.sortDate }
        }
        byZone[.vibes]?.sort { $0.createdAt > $1.createdAt }
    }

    func drops(in zone: Zone) -> [Drop] {
        byZone[zone] ?? []
    }

    var isEmpty: Bool {
        arriving.isEmpty && byZone.values.allSatisfy(\.isEmpty)
    }
}
