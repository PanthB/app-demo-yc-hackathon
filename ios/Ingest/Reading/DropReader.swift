import AVFoundation
import Foundation
import os

enum DropReader {
    struct Seen: Sendable {
        var reading = DropReading()
        var thumbnailPath: String?
        var cutoutPath: String?
        var duration: Double?
    }

    @MainActor
    static func read(_ drop: Drop, in container: URL) async -> DropReading {
        let id = drop.id
        if let done = DropReading.load(for: id, in: container), done.finished { return done }
        readWords(of: drop)
        readLink(of: drop)
        let seen = await look(kind: drop.sourceKind, id: id, mediaPaths: drop.mediaPaths, container: container)
        if let path = seen.thumbnailPath { drop.thumbnailPath = path }
        if let path = seen.cutoutPath { drop.cutoutPath = path }
        if let duration = seen.duration { drop.mediaDuration = duration }
        if drop.sourceKind == .image, seen.cutoutPath == nil { drop.objectKind = .polaroid }
        var reading = seen.reading
        reading.finished = true
        reading.save(for: id, in: container)
        return reading
    }

    @MainActor
    static func readWords(of drop: Drop, calendar: Calendar = .current) {
        guard drop.sourceKind == .text, let text = drop.rawText,
              let time = TimeWords.parse(text, now: drop.createdAt, calendar: calendar)
        else { return }
        drop.dueAt = time.dueAt
        drop.startsAt = time.startsAt
        drop.whenLabel = time.whenLabel
        drop.applyDecidedZone(time.zone, unsure: false)
    }

    @MainActor
    static func readLink(of drop: Drop) {
        guard drop.sourceKind == .url, let link = drop.url else { return }
        let seen = LinkReading.read(link, caption: drop.rawText)
        if let title = seen.title { drop.title = title }
        if let artist = seen.artist { drop.artist = artist }
        if let place = seen.placeName { drop.placeName = place }
        if let latitude = seen.latitude, let longitude = seen.longitude {
            drop.latitude = latitude
            drop.longitude = longitude
        }
    }

    static func look(kind: SourceKind, id: UUID, mediaPaths: [String], container: URL) async -> Seen {
        var seen = Seen()
        guard let first = mediaPaths.first.map({ container.appending(path: $0) }) else { return seen }
        let folderPath = InboxIngest.mediaFolder(for: id)
        let folder = container.appending(path: folderPath, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        switch kind {
        case .image:
            guard let image = ImageFiles.downsampled(first, maxPixel: 1600) else {
                seen.reading.notes.append("the picture couldn't be opened")
                break
            }
            if ImageFiles.writeJPEG(image, to: folder.appending(path: "thumb.jpg")) {
                seen.thumbnailPath = "\(folderPath)/thumb.jpg"
                seen.reading.uploadPaths = ["\(folderPath)/thumb.jpg"]
            }
            switch ImageReading.liftSubject(from: image, to: folder.appending(path: "cutout.png")) {
            case .saved:
                seen.cutoutPath = "\(folderPath)/cutout.png"
            case .noSubject:
                seen.reading.notes.append("no subject stood out, so this stays a whole photo")
            case let .unavailable(why):
                seen.reading.notes.append("subject lifting isn't available here, so this stays a whole photo: \(why)")
            }
        case .video:
            let frames = await VideoReading.frames(of: first, into: folder)
            seen.reading.uploadPaths = frames.map { "\(folderPath)/\($0.lastPathComponent)" }
            seen.thumbnailPath = seen.reading.uploadPaths.dropFirst().first ?? seen.reading.uploadPaths.first
            seen.duration = await duration(of: first)
            if frames.isEmpty { seen.reading.notes.append("no frames could be taken from the video") }
        case .audio:
            let heard = await AudioReading.transcribe(first)
            seen.reading.transcript = heard.text
            if let note = heard.note { seen.reading.notes.append(note) }
            seen.duration = await duration(of: first)
        case .pdf:
            let pdf = PDFReading.read(first)
            seen.reading.pdfText = pdf.text.map { String($0.prefix(4000)) }
            if let page = pdf.firstPage, ImageFiles.writeJPEG(page, to: folder.appending(path: "page.jpg")) {
                seen.thumbnailPath = "\(folderPath)/page.jpg"
                seen.reading.uploadPaths = ["\(folderPath)/page.jpg"]
            }
            if pdf.text == nil { seen.reading.notes.append("the pdf has no text layer to read") }
        case .url, .text:
            break
        }
        for note in seen.reading.notes {
            Logger.ingest.info("reading \(id.uuidString, privacy: .public): \(note, privacy: .public)")
        }
        return seen
    }

    private static func duration(of url: URL) async -> Double? {
        guard let seconds = try? await AVURLAsset(url: url).load(.duration).seconds, seconds.isFinite, seconds > 0 else { return nil }
        return seconds
    }
}
