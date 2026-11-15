import Combine
import ConvexMobile
import Foundation
import Observation
import os
import SwiftData

extension Logger {
    static let sync = Logger(subsystem: subsystem, category: "sync")
}

@MainActor
@Observable
final class BoardSync {
    let boards: BoardsStore

    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var listeners: [String: AnyCancellable] = [:]
    @ObservationIgnored private var clientIds: [UUID: String] = [:]
    @ObservationIgnored private var sending: Set<UUID> = []
    @ObservationIgnored private var placing: [UUID: Int] = [:]
    @ObservationIgnored private var pictured: Set<UUID> = []
    @ObservationIgnored private var located: Set<UUID> = []
    @ObservationIgnored private var retry: Task<Void, Never>?

    private static let staysOffline: Bool = {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return true }
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "BoardDebugSeed")
        #else
        return false
        #endif
    }()

    init(boards: BoardsStore) {
        self.boards = boards
        boards.onChange = { [weak self] in self?.follow() }
    }

    func wake(in context: ModelContext) {
        self.context = context
        InboxIngest.appGroup?.run(in: context)
        guard !Self.staysOffline else { return }
        boards.start()
        follow()
        sendWaiting()
    }

    func setPinned(_ drop: Drop, _ pinned: Bool) {
        drop.setPinned(pinned)
        save("pinning")
        push("drops:setPinned", for: drop, ["pinned": pinned])
    }

    func move(_ drop: Drop, to zone: Zone) {
        drop.moveByUser(to: zone)
        save("moving")
        push("drops:setZone", for: drop, ["zone": zone.rawValue])
    }

    func markDone(_ drop: Drop) {
        move(drop, to: .done)
    }

    func undoMove(_ drop: Drop) {
        guard drop.canUndoMove else { return }
        drop.undoMove()
        save("undoing a move")
        push("drops:setZone", for: drop, ["zone": drop.zoneRaw])
    }

    private func follow() {
        guard context != nil, !Self.staysOffline else { return }
        let wanted = Set(boards.boardIds)
        for id in listeners.keys where !wanted.contains(id) {
            listeners.removeValue(forKey: id)?.cancel()
        }
        for id in wanted where listeners[id] == nil {
            listeners[id] = convex.subscribe(to: "drops:list", with: ["boardId": id], yielding: LossyList<RemoteDrop>.self)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    MainActor.assumeIsolated {
                        if case let .failure(error) = completion {
                            Logger.sync.error("the board \(id, privacy: .public) stopped updating: \(String(describing: error), privacy: .public)")
                        }
                        self?.listeners[id] = nil
                        self?.retrySoon()
                    }
                }, receiveValue: { [weak self] list in
                    MainActor.assumeIsolated {
                        self?.take(list, from: id)
                    }
                })
        }
    }

    private func take(_ list: LossyList<RemoteDrop>, from boardId: String) {
        guard let context else { return }
        if list.skipped > 0 {
            Logger.sync.error("\(list.skipped) drops in \(boardId, privacy: .public) couldn't be read and were left out")
        }
        let local = (try? context.fetch(FetchDescriptor<Drop>())) ?? []
        var byId = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var arrived = 0
        for remote in list.elements {
            let id = DropKey.id(for: remote.clientId)
            clientIds[id] = remote.clientId
            let drop: Drop
            if let known = byId[id] {
                drop = known
            } else {
                drop = remote.makeDrop(id: id)
                context.insert(drop)
                byId[id] = drop
                arrived += 1
            }
            remote.apply(to: drop, holdingPlacement: placing[id] != nil)
            fetchPicture(for: drop, from: remote.thumbnailUrl)
            locate(drop, in: remote.extraction?.area)
        }
        save("reading the board \(boardId)")
        if arrived > 0 {
            Logger.sync.info("\(arrived) new drops arrived in \(boardId, privacy: .public)")
        }
    }

    private func sendWaiting() {
        guard let context else { return }
        let pending = DropStatus.pending.rawValue
        let waiting = (try? context.fetch(FetchDescriptor<Drop>(
            predicate: #Predicate { $0.remoteId == nil && $0.statusRaw == pending },
            sortBy: [SortDescriptor(\.createdAt)]
        ))) ?? []
        for drop in waiting where sending.insert(drop.id).inserted {
            Task {
                await send(drop)
                sending.remove(drop.id)
            }
        }
    }

    private func send(_ drop: Drop) async {
        guard let container = AppGroup.containerURL else { return }
        let id = drop.id
        var reading = await DropReader.read(drop, in: container)
        save("reading a drop on this phone")
        do {
            while reading.storageIds.count < min(reading.uploadPaths.count, 4) {
                let path = reading.uploadPaths[reading.storageIds.count]
                reading.storageIds.append(try await Uploads.send(container.appending(path: path)))
                reading.save(for: id, in: container)
            }
            let boardId = drop.boardId.isEmpty ? BoardKeys.personalBoard : drop.boardId
            let remoteId: String = try await convex.mutation(
                "drops:submit",
                with: DropSubmit.arguments(for: drop, reading: reading, boardId: boardId, personId: drop.authorId)
            )
            drop.remoteId = remoteId
            if drop.boardId.isEmpty { drop.boardId = boardId }
            save("sending a drop")
            Logger.sync.info("sent the \(drop.sourceKindRaw, privacy: .public) drop \(id.uuidString, privacy: .public) with \(reading.storageIds.count) pictures")
            if drop.zoneSetByUser { push("drops:setZone", for: drop, ["zone": drop.zoneRaw]) }
            if drop.isPinned { push("drops:setPinned", for: drop, ["pinned": true]) }
        } catch {
            Logger.sync.error("couldn't send the drop \(id.uuidString, privacy: .public), so it stays on this phone and goes out later: \(String(describing: error), privacy: .public)")
            retrySoon()
        }
    }

    private func push(_ function: String, for drop: Drop, _ change: [String: ConvexEncodable?]) {
        guard drop.remoteId != nil else { return }
        let id = drop.id
        var args = change
        args.updateValue(drop.boardId, forKey: "boardId")
        args.updateValue(clientIds[id] ?? id.uuidString, forKey: "clientId")
        placing[id, default: 0] += 1
        Task {
            do {
                try await convex.mutation(function, with: args)
            } catch {
                Logger.sync.error("\(function, privacy: .public) didn't reach the backend for \(id.uuidString, privacy: .public): \(String(describing: error), privacy: .public)")
            }
            let left = (placing[id] ?? 1) - 1
            placing[id] = left > 0 ? left : nil
        }
    }

    private func fetchPicture(for drop: Drop, from link: String?) {
        guard drop.thumbnailPath == nil, drop.cutoutPath == nil,
              let url = link.flatMap({ URL(string: $0.replacingOccurrences(of: "http://", with: "https://", options: .anchored)) }),
              let container = AppGroup.containerURL,
              pictured.insert(drop.id).inserted
        else { return }
        let folderPath = InboxIngest.mediaFolder(for: drop.id)
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let folder = container.appending(path: folderPath, directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                guard let image = ImageFiles.downsampled(data, maxPixel: 1200),
                      ImageFiles.writeJPEG(image, to: folder.appending(path: "remote.jpg"))
                else { throw CocoaError(.fileReadCorruptFile) }
                drop.thumbnailPath = "\(folderPath)/remote.jpg"
                save("keeping a picture")
            } catch {
                Logger.sync.error("no picture for \(drop.id.uuidString, privacy: .public) from \(url.host() ?? "its link", privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func locate(_ drop: Drop, in area: String?) {
        guard let name = drop.placeName, drop.latitude == nil, located.insert(drop.id).inserted else { return }
        let query = [name, area].compactMap { $0 }.joined(separator: ", ")
        Task {
            guard let place = await PlaceFinder.find(query, nearLatitude: drop.anchorLatitude, nearLongitude: drop.anchorLongitude) else { return }
            drop.latitude = place.latitude
            drop.longitude = place.longitude
            save("finding a place")
        }
    }

    private func retrySoon() {
        guard retry == nil else { return }
        retry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard let self else { return }
            self.retry = nil
            self.follow()
            self.sendWaiting()
        }
    }

    private func save(_ what: String) {
        guard let context, context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            Logger.sync.error("saving after \(what, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        }
    }
}
