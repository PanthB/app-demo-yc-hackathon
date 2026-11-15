import Foundation
import os

struct DropReading: Codable, Equatable, Sendable {
    var finished = false
    var transcript: String?
    var pdfText: String?
    var uploadPaths: [String] = []
    var storageIds: [String] = []
    var notes: [String] = []

    static func url(for id: UUID, in container: URL) -> URL {
        container.appending(path: "\(InboxIngest.mediaFolder(for: id))/read.json")
    }

    static func load(for id: UUID, in container: URL) -> DropReading? {
        guard let data = try? Data(contentsOf: url(for: id, in: container)) else { return nil }
        return try? JSONDecoder().decode(DropReading.self, from: data)
    }

    func save(for id: UUID, in container: URL) {
        let url = Self.url(for: id, in: container)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(self).write(to: url, options: .atomic)
        } catch {
            Logger.ingest.error("couldn't save what was read for \(id.uuidString, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }
}
