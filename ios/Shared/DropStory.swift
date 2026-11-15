import Foundation
import os
import SwiftData

enum DropStory {
    static func dropped(_ drop: Drop, now: Date, calendar: Calendar = .current) -> String {
        let when = day(drop.createdAt, now: now, calendar: calendar)
        if drop.sourceKind == .text {
            return "you wrote this \(when)."
        }
        return "you dropped this from \(source(of: drop)) \(when)."
    }

    static func source(of drop: Drop) -> String {
        let host = drop.linkHost ?? ""
        switch drop.sourceKind {
        case .image: return "photos"
        case .video: return host.isEmpty ? "a video" : host
        case .audio: return "a voice note"
        case .pdf: return "a pdf"
        case .text: return "a note"
        case .url:
            if host.hasSuffix("tiktok.com") { return "tiktok" }
            if host.hasSuffix("instagram.com") { return "instagram" }
            if host.hasSuffix("spotify.com") || host.hasSuffix("music.apple.com") { return "a song link" }
            return host.isEmpty ? "a link" : host
        }
    }

    static func day(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "today" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days == 1 { return "yesterday" }
        if days < 7 {
            let names = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
            return "on \(names[calendar.component(.weekday, from: date) - 1])"
        }
        return "on \(DropFace.dateTag(date, now: now, calendar: calendar))"
    }
}

enum BoardSave {
    @MainActor
    static func save(_ context: ModelContext, _ what: String) {
        do {
            try context.save()
        } catch {
            Logger.store.error("\(what, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        }
    }
}

enum UndoWords {
    static func sentence(for zone: Zone) -> String {
        switch zone {
        case .now: "that's up now. tap here to put it back."
        case .tonight: "that's on tonight now. tap here to put it back."
        case .thisWeekend: "that's on this weekend now. tap here to put it back."
        case .someday: "that's saved for someday. tap here to put it back."
        case .vibes: "that's in vibes now. tap here to put it back."
        case .done: "that's done. tap here to put it back."
        }
    }
}
