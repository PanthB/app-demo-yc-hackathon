import SwiftUI
import UIKit

enum PreviewFace {
    case image(UIImage)
    case cutout(UIImage)
    case words(String)
    case date(top: String, day: String)
    case countdown(Date)
    case waveform(length: String?)
    case symbol(String)

    var words: String? {
        if case .words(let words) = self { return words }
        return nil
    }

    var ratio: CGFloat {
        switch self {
        case .image(let image):
            guard image.size.width > 0 else { return 1 }
            return min(max(image.size.height / image.size.width, 0.75), 1.5)
        case .cutout:
            return 1
        case .words(let words):
            return words.count > 40 ? 1 : 0.75
        case .date, .countdown, .waveform, .symbol:
            return 0.75
        }
    }
}

extension Drop {
    var kind: DropKind {
        DropKind.derive(type: type, source: sourceKind, hasDueTime: dueAt != nil)
    }

    var cardAuthorId: String { dropperId }

    var cardAuthorName: String { "me" }

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
        case .link:
            if let host = linkHost { return .words(host) }
        case .photo, .video, .song, .place:
            break
        }
        return .symbol(kind.symbol)
    }

    func cardTitle(beside face: PreviewFace) -> String? {
        CardWords.title([title, rawText], hiding: face.words)
    }

    func cardMeta(now: Date, beside face: PreviewFace, calendar: Calendar = .current) -> String? {
        let when = dueAt.map { DropFace.dateTag($0, now: now, calendar: calendar) } ?? tag(now: now, calendar: calendar)
        let place = kind == .song ? artist : placeName ?? (kind == .link ? linkHost : nil)
        return CardWords.meta([when, place], hiding: face.words)
    }

    func suggestion(now: Date) -> DropSuggestion? {
        guard zone != .done, dueAt == nil, let startsAt else { return nil }
        let wait = startsAt.timeIntervalSince(now)
        return wait > 60 && wait <= ZoneClock.soonWindow ? .startsSoon(startsAt) : nil
    }

    func spokenLabel(now: Date, beside face: PreviewFace) -> String {
        [kind.word, cardTitle(beside: face) ?? face.words, cardMeta(now: now, beside: face), "saved by \(cardAuthorName)", pinned ? "pinned" : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
