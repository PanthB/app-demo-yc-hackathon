import SwiftUI
import UIKit

enum PreviewFace {
    case image(UIImage)
    case cutout(UIImage)
    case words(String)
    case date(top: String, day: String)
    case countdown(Date)
    case waveform(length: String?)
    case plain

    var words: String? {
        if case .words(let words) = self { return words }
        return nil
    }

    var isPicture: Bool {
        if case .image = self { return true }
        return false
    }

    var drawsSmall: Bool {
        switch self {
        case .image, .cutout, .date, .countdown, .waveform: true
        case .words, .plain: false
        }
    }

    var fillsItsFrame: Bool {
        switch self {
        case .image, .cutout: true
        case .words, .date, .countdown, .waveform, .plain: false
        }
    }

    var ratio: CGFloat {
        switch self {
        case .image(let image):
            guard image.size.width > 0 else { return 1 }
            return min(max(image.size.height / image.size.width, 0.75), 1.5)
        case .cutout(let image):
            guard image.size.width > 0 else { return 1 }
            return min(max(image.size.height / image.size.width, 0.75), 1.25)
        case .words, .date, .countdown, .waveform, .plain:
            return 0.75
        }
    }
}

extension Drop {
    var kind: DropKind {
        DropKind.derive(type: type, source: sourceKind, hasDueTime: dueAt != nil, link: url, hasLength: mediaDuration != nil)
    }

    var authorLabel: String {
        CardWords.clean(authorName) ?? "me"
    }

    func previewFace(now: Date, calendar: Calendar = .current) -> PreviewFace {
        if let image = MediaStore.image(at: thumbnailPath) { return .image(image) }
        if let image = MediaStore.image(at: cutoutPath) { return .cutout(image) }
        if sourceKind == .image, let image = MediaStore.image(at: mediaPaths.first) { return .image(image) }
        switch kind {
        case .reminder:
            guard let dueAt else { break }
            let left = dueAt.timeIntervalSince(now)
            return left > 0 && left < 86400 ? .countdown(dueAt) : .words(DropFace.countdown(until: dueAt, now: now, calendar: calendar))
        case .event:
            if let startsAt {
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: startsAt)).day ?? 0
                let top = (0...6).contains(days) ? startsAt.formatted(.dateTime.weekday(.abbreviated)) : startsAt.formatted(.dateTime.month(.abbreviated))
                return .date(top: top.lowercased(), day: startsAt.formatted(.dateTime.day()))
            }
            if let when = CardWords.clean(whenLabel) { return .words(when) }
        case .voice:
            return .waveform(length: mediaDuration.map(DropFace.duration))
        case .note:
            if let words = CardWords.clean(rawText) ?? CardWords.clean(title) { return .words(words) }
        case .link, .photo, .video, .song, .place:
            break
        }
        if cardTitle(beside: .plain) != nil { return .plain }
        return .words(CardWords.unread(kind, from: authorId == DeviceIdentity.personId ? nil : authorLabel))
    }

    func pictureURL(for face: PreviewFace) -> URL? {
        guard case .image = face else { return nil }
        let path = MediaStore.image(at: thumbnailPath) != nil ? thumbnailPath : (sourceKind == .image ? mediaPaths.first : nil)
        return path.flatMap(MediaStore.url(for:))
    }

    func cardTitle(beside face: PreviewFace) -> String? {
        CardWords.title([title, rawText], hiding: face.words)
    }

    func cardMeta(now: Date, beside face: PreviewFace, calendar: Calendar = .current) -> String? {
        let when = dueAt.map { DropFace.dateTag($0, now: now, calendar: calendar) } ?? tag(now: now, calendar: calendar)
        let from: [String?] = switch kind {
        case .song: [artist, CardWords.clean(genre) ?? Vibes.genre(in: vibes)]
        case .video: [artist ?? placeName, DropKind.clipSite(link: url, hasLength: mediaDuration != nil)]
        case .link: [placeName ?? linkHost]
        default: [placeName, Vibes.neighborhood(in: vibes)]
        }
        return CardWords.meta([when] + from, hiding: [face.words, cardTitle(beside: face)])
    }

    func playBadge(on face: PreviewFace) -> ClipBadge? {
        guard face.fillsItsFrame, kind == .video || (kind == .song && mediaDuration != nil) else { return nil }
        return ClipBadge(length: mediaDuration.map(DropFace.duration))
    }

    func liveSuggestion(now: Date) -> DropSuggestion? {
        if isArriving { return .words("reading this one now.") }
        guard zone != .done else { return nil }
        if dueAt == nil, let startsAt {
            let wait = startsAt.timeIntervalSince(now)
            if wait > 60 && wait <= ZoneClock.soonWindow { return .soon(startsAt, lead: kind == .place ? "that's" : "starts") }
        }
        return CardWords.clean(suggestion).map(DropSuggestion.words)
    }

    func spokenLabel(now: Date, beside face: PreviewFace) -> String {
        [kind.word, cardTitle(beside: face) ?? face.words, cardMeta(now: now, beside: face), "saved by \(authorLabel)", isPinned ? "pinned" : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
