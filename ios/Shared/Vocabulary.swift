import Foundation

enum Zone: String, Codable, CaseIterable, Sendable {
    case now, tonight, thisWeekend, someday, vibes, done
}

enum DropType: String, Codable, CaseIterable, Sendable {
    case place, event, song, mood, note
}

enum ObjectKind: String, Codable, CaseIterable, Sendable {
    case cutout, polaroid, record, slip, sticky, stub, postcard
}

enum BoardMode: String, Codable, CaseIterable, Sendable {
    case planning, wandering, collision, memory
}

enum Emphasis: String, Codable, CaseIterable, Sendable {
    case normal, grow, pulseOnce, curl
}

enum DropStatus: String, Codable, CaseIterable, Sendable {
    case pending, processed, failed
}

enum SourceKind: String, Codable, CaseIterable, Sendable {
    case url, image, video, audio, text, pdf

    var defaultObjectKind: ObjectKind {
        switch self {
        case .url: .postcard
        case .image: .cutout
        case .video: .polaroid
        case .audio: .slip
        case .text: .sticky
        case .pdf: .stub
        }
    }
}
