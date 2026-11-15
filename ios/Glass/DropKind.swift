import Foundation

enum DropKind: String, CaseIterable, Sendable {
    case photo, video, song, place, event, link, note, voice, reminder

    var word: String {
        self == .video ? "clip" : rawValue
    }

    var openWord: String {
        switch self {
        case .song: "listen"
        case .video: "watch"
        case .place: "visit"
        case .photo, .event, .link, .note, .voice, .reminder: "open"
        }
    }

    var symbol: String {
        switch self {
        case .photo: "photo"
        case .video: "play.rectangle"
        case .song: "music.note"
        case .place: "mappin"
        case .event: "ticket"
        case .link: "link"
        case .note: "note.text"
        case .voice: "waveform"
        case .reminder: "timer"
        }
    }

    static func derive(type: DropType?, source: SourceKind, hasDueTime: Bool, link: String? = nil, hasLength: Bool = false) -> DropKind {
        if hasDueTime { return .reminder }
        if source == .video || clipSite(link: link, hasLength: hasLength) != nil { return .video }
        switch type {
        case .song: return .song
        case .event: return .event
        case .place: return .place
        case .mood, .note, nil: break
        }
        switch source {
        case .image: return .photo
        case .video: return .video
        case .audio: return .voice
        case .url: return .link
        case .text, .pdf: return .note
        }
    }
}

extension DropKind {
    private static let clipSites = [
        (host: "tiktok.com", name: "tiktok"),
        (host: "youtube.com", name: "youtube"),
        (host: "youtu.be", name: "youtube"),
        (host: "vimeo.com", name: "vimeo"),
        (host: "instagram.com", name: "instagram"),
    ]

    static func clipSite(link: String?, hasLength: Bool = false) -> String? {
        guard let link, let parts = URLComponents(string: link), let host = parts.host?.lowercased(),
              let site = clipSites.first(where: { host == $0.host || host.hasSuffix(".\($0.host)") })
        else { return nil }
        if site.name == "instagram", !hasLength, !parts.path.hasPrefix("/reel"), !parts.path.hasPrefix("/tv") { return nil }
        return site.name
    }
}

enum Vibes {
    static let neighborhoods: Set<String> = [
        "mission", "castro", "haight", "hayes valley", "nopa", "north beach", "chinatown", "japantown", "marina",
        "presidio", "golden gate park", "sunset", "richmond", "soma", "embarcadero", "dogpatch", "noe valley", "lands end",
        "tenderloin", "union square",
    ]
    static let genres: Set<String> = ["pop", "indie", "rock", "hip hop", "r&b", "electronic", "jazz", "folk", "country", "soul", "classical"]

    static func neighborhood(in vibes: [String]) -> String? {
        vibes.lazy.map { $0.lowercased() }.first(where: neighborhoods.contains)
    }

    static func genre(in vibes: [String]) -> String? {
        vibes.lazy.map { $0.lowercased() }.first(where: genres.contains)
    }
}

enum CardWords {
    static func title(_ candidates: [String?], hiding shown: String?) -> String? {
        let hidden = clean(shown)
        return candidates.lazy.compactMap(clean).first { $0 != hidden }
    }

    static func meta(_ parts: [String?], hiding shown: [String?]) -> String? {
        var seen = shown.compactMap(clean)
        let hidden = seen.count
        for part in parts.compactMap(clean) where !seen.contains(part) {
            seen.append(part)
        }
        return seen.count == hidden ? nil : seen.dropFirst(hidden).joined(separator: " · ")
    }

    static func unread(_ kind: DropKind, from name: String?) -> String {
        let thing = "\("aeiou".contains(kind.word.prefix(1)) ? "an" : "a") \(kind.word)"
        guard let name = clean(name) else { return "\(thing) you saved" }
        return "\(thing) from \(name)"
    }

    static func saver(_ name: String?, isMe: Bool) -> String {
        isMe ? "you" : clean(name) ?? "someone"
    }

    static func clean(_ words: String?) -> String? {
        guard let words else { return nil }
        let trimmed = words.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum PersonMark {
    static func initial(of name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "?"
    }

    static func colorIndex(for personId: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in personId.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
        return Int(hash % UInt64(count))
    }
}

extension Zone {
    static func moveTargets(from current: Zone) -> [Zone] {
        allCases.filter { $0 != .done && $0 != current }
    }
}
