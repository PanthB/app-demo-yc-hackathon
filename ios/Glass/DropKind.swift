import Foundation

enum DropKind: String, CaseIterable, Sendable {
    case photo, video, song, place, event, link, note, voice, reminder

    var word: String { rawValue }

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

    static func derive(type: DropType?, source: SourceKind, hasDueTime: Bool) -> DropKind {
        if hasDueTime { return .reminder }
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

enum CardWords {
    static func title(_ candidates: [String?], hiding shown: String?) -> String? {
        let hidden = clean(shown)
        return candidates.lazy.compactMap(clean).first { $0 != hidden }
    }

    static func meta(_ parts: [String?], hiding shown: String?) -> String? {
        let hidden = clean(shown)
        var seen: [String] = []
        for part in parts.compactMap(clean) where part != hidden && !seen.contains(part) {
            seen.append(part)
        }
        return seen.isEmpty ? nil : seen.joined(separator: " · ")
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
