import Foundation
import ImageIO
import os
import UIKit
import UniformTypeIdentifiers

struct GatheredFile {
    var kind: SourceKind
    var url: URL
}

struct GatheredShare {
    var title: String?
    var link: String?
    var texts: [String] = []
    var files: [GatheredFile] = []
}

struct PlannedDrop {
    var item: InboxItem
    var payloads: [InboxPayload]
}

enum ShareCollector {
    static func save(_ items: [NSExtensionItem], to inbox: Inbox) async -> [InboxItem] {
        let scratch = FileManager.default.temporaryDirectory
            .appending(path: "share-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let share = await gather(items, scratch: scratch)
        var saved: [InboxItem] = []
        for drop in plan(share) {
            do {
                let written = try inbox.write(drop.item, payloads: drop.payloads)
                Logger.share.info("dropped a \(written.kind.rawValue, privacy: .public) as \(written.id.uuidString, privacy: .public) with \(written.files.count) files")
                saved.append(written)
            } catch {
                Logger.share.error("writing a \(drop.item.kind.rawValue, privacy: .public) drop to the inbox failed: \(String(describing: error), privacy: .public)")
            }
        }
        return saved
    }

    static func plan(_ share: GatheredShare) -> [PlannedDrop] {
        var seen = Set<String>()
        let words = ([share.title] + share.texts)
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != share.link && seen.insert($0).inserted }
        let note = words.isEmpty ? nil : words.joined(separator: "\n")

        if let link = share.link {
            var names = Set<String>()
            let payloads = share.files.enumerated().map { index, file in
                let name = file.url.lastPathComponent
                return InboxPayload.file(file.url, name: names.insert(name).inserted ? name : "\(index)-\(name)")
            }
            return [PlannedDrop(item: InboxItem(kind: .url, text: note, url: link), payloads: payloads)]
        }

        if !share.files.isEmpty {
            return share.files.enumerated().map { index, file in
                let location = file.kind == .image ? photoLocation(at: file.url) : nil
                let item = InboxItem(
                    kind: file.kind,
                    text: index == 0 ? note : nil,
                    latitude: location?.latitude,
                    longitude: location?.longitude
                )
                return PlannedDrop(item: item, payloads: [.file(file.url, name: file.url.lastPathComponent)])
            }
        }

        guard let note else { return [] }
        if let link = soleLink(note) {
            return [PlannedDrop(item: InboxItem(kind: .url, url: link), payloads: [])]
        }
        return [PlannedDrop(item: InboxItem(kind: .text, text: note, url: firstLink(in: note)), payloads: [])]
    }

    static func kind(for type: UTType) -> SourceKind? {
        if type.conforms(to: .movie) { return .video }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .image) { return .image }
        return nil
    }

    static func photoLocation(at url: URL) -> (latitude: Double, longitude: Double)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
              let longitude = gps[kCGImagePropertyGPSLongitude] as? Double
        else { return nil }
        let south = (gps[kCGImagePropertyGPSLatitudeRef] as? String) == "S"
        let west = (gps[kCGImagePropertyGPSLongitudeRef] as? String) == "W"
        return (south ? -latitude : latitude, west ? -longitude : longitude)
    }

    private static func soleLink(_ text: String) -> String? {
        guard !text.contains(where: \.isWhitespace),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url.host() != nil
        else { return nil }
        return text
    }

    private static func firstLink(in text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let match = detector?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        guard let url = match?.url, url.scheme == "http" || url.scheme == "https" else { return nil }
        return url.absoluteString
    }

    private static func gather(_ items: [NSExtensionItem], scratch: URL) async -> GatheredShare {
        var share = GatheredShare()
        share.title = items
            .compactMap { ($0.attributedTitle ?? $0.attributedContentText)?.string }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for provider in items.flatMap({ $0.attachments ?? [] }) {
            let media = provider.registeredTypeIdentifiers.lazy
                .compactMap { identifier in UTType(identifier).flatMap { type in kind(for: type).map { (kind: $0, identifier: identifier) } } }
                .first
            if let media {
                let folder = scratch.appending(path: String(share.files.count), directoryHint: .isDirectory)
                if let url = await copyFile(from: provider, type: media.identifier, isImage: media.kind == .image, into: folder) {
                    share.files.append(GatheredFile(kind: media.kind, url: url))
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                guard let url = await loadURL(from: provider) else { continue }
                if !url.isFileURL {
                    share.link = share.link ?? url.absoluteString
                } else if let kind = UTType(filenameExtension: url.pathExtension).flatMap(kind(for:)) {
                    let folder = scratch.appending(path: String(share.files.count), directoryHint: .isDirectory)
                    let scoped = url.startAccessingSecurityScopedResource()
                    if let copy = keep(url, in: folder) {
                        share.files.append(GatheredFile(kind: kind, url: copy))
                    }
                    if scoped { url.stopAccessingSecurityScopedResource() }
                } else {
                    Logger.share.error("a shared file of type \(url.pathExtension, privacy: .public) isn't something the board keeps yet")
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let text = await loadText(from: provider) {
                    share.texts.append(text)
                }
            } else {
                Logger.share.error("skipped an attachment with types \(provider.registeredTypeIdentifiers.joined(separator: ", "), privacy: .public)")
            }
        }
        return share
    }

    private static func copyFile(from provider: NSItemProvider, type: String, isImage: Bool, into folder: URL) async -> URL? {
        let copied: URL? = await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                guard let url else {
                    Logger.share.error("no file came through for \(type, privacy: .public): \(String(describing: error), privacy: .public)")
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: keep(url, in: folder))
            }
        }
        if copied != nil || !isImage { return copied }

        do {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.image.identifier)
            if let url = item as? URL {
                return keep(url, in: folder)
            }
            let data = (item as? Data) ?? (item as? UIImage)?.jpegData(compressionQuality: 0.9)
            guard let data else { return nil }
            let name = (item is UIImage) ? "image.jpg" : "image.\(UTType(type)?.preferredFilenameExtension ?? "jpg")"
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appending(path: name)
            try data.write(to: destination)
            return destination
        } catch {
            Logger.share.error("the image fallback failed too: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private static func keep(_ source: URL, in folder: URL) -> URL? {
        let name = source.lastPathComponent.isEmpty ? "drop" : source.lastPathComponent
        let destination = folder.appending(path: name)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        } catch {
            Logger.share.error("copying \(name, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        do {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
            if let url = item as? URL { return url }
            if let text = item as? String { return URL(string: text) }
            if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
            return nil
        } catch {
            Logger.share.error("loading a link failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private static func loadText(from provider: NSItemProvider) async -> String? {
        do {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
            if let text = item as? String { return text }
            if let attributed = item as? NSAttributedString { return attributed.string }
            if let data = item as? Data { return String(data: data, encoding: .utf8) }
            if let url = item as? URL, url.isFileURL { return try String(contentsOf: url, encoding: .utf8) }
            return nil
        } catch {
            Logger.share.error("loading text failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
