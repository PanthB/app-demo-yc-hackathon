import Foundation
import os
import SwiftData

extension Logger {
    static let ingest = Logger(subsystem: subsystem, category: "ingest")
}

@MainActor
struct InboxIngest {
    var inbox: Inbox
    var container: URL
    var dropperId: String

    static var appGroup: InboxIngest? {
        guard let inbox = Inbox.shared, let container = AppGroup.containerURL else {
            Logger.ingest.fault("app group is missing, so shared drops can't reach the board")
            return nil
        }
        return InboxIngest(inbox: inbox, container: container, dropperId: DeviceIdentity.personId)
    }

    nonisolated static func mediaFolder(for id: UUID) -> String {
        "media/\(id.uuidString)"
    }

    @discardableResult
    func run(in context: ModelContext) -> [UUID] {
        var created: [UUID] = []
        for item in inbox.pending() {
            do {
                if try !isOnBoard(item.id, in: context) {
                    let drop = Drop(
                        id: item.id,
                        createdAt: item.createdAt,
                        authorId: dropperId,
                        sourceKind: item.kind,
                        rawText: item.text,
                        url: item.url,
                        mediaPaths: try copyFiles(of: item)
                    )
                    drop.anchorLatitude = item.latitude
                    drop.anchorLongitude = item.longitude
                    context.insert(drop)
                    do {
                        try context.save()
                    } catch {
                        context.rollback()
                        throw error
                    }
                    created.append(item.id)
                    Logger.ingest.info("put a \(item.kind.rawValue, privacy: .public) drop on the board as \(item.id.uuidString, privacy: .public)")
                }
            } catch {
                Logger.ingest.error("couldn't move \(item.id.uuidString, privacy: .public) from the inbox to the board, so it stays in the inbox: \(String(describing: error), privacy: .public)")
                continue
            }
            do {
                try inbox.remove(item.id)
            } catch {
                Logger.ingest.error("\(item.id.uuidString, privacy: .public) is on the board but its inbox folder is still there: \(String(describing: error), privacy: .public)")
            }
        }
        return created
    }

    private func isOnBoard(_ id: UUID, in context: ModelContext) throws -> Bool {
        try context.fetchCount(FetchDescriptor<Drop>(predicate: #Predicate { $0.id == id })) > 0
    }

    private func copyFiles(of item: InboxItem) throws -> [String] {
        let fileManager = FileManager.default
        let folderPath = Self.mediaFolder(for: item.id)
        let folder = container.appending(path: folderPath, directoryHint: .isDirectory)
        var paths: [String] = []
        for name in item.files {
            let source = inbox.fileURL(name, in: item)
            guard fileManager.fileExists(atPath: source.path) else {
                Logger.ingest.error("\(name, privacy: .public) is listed for \(item.id.uuidString, privacy: .public) but isn't in its inbox folder")
                continue
            }
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appending(path: name)
            try? fileManager.removeItem(at: destination)
            try fileManager.copyItem(at: source, to: destination)
            paths.append("\(folderPath)/\(name)")
        }
        return paths
    }
}
