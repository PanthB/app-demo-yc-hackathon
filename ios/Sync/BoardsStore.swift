import Combine
import ConvexMobile
import Foundation
import Observation
import os

enum BoardEntry: Identifiable, Equatable {
    case create
    case join(code: String?)

    var id: String {
        switch self {
        case .create: "create"
        case .join: "join"
        }
    }
}

struct BoardProblem: LocalizedError {
    var message: String

    var errorDescription: String? { message }
}

@MainActor
@Observable
final class BoardsStore {
    private(set) var boards: [RemoteBoard] = []
    private(set) var currentBoardId: String
    private(set) var personName: String?
    var entry: BoardEntry?

    @ObservationIgnored var onChange: () -> Void = {}
    @ObservationIgnored private var person: String?
    @ObservationIgnored private var listener: AnyCancellable?

    init() {
        #if DEBUG
        if let debugPerson = UserDefaults.standard.string(forKey: "BoardDebugPerson"), !debugPerson.isEmpty,
           debugPerson != DeviceIdentity.personId {
            DeviceIdentity.adopt(personId: debugPerson)
            Logger.sync.info("this device is now \(debugPerson, privacy: .public)")
        }
        #endif
        currentBoardId = BoardKeys.currentBoard
        personName = AppGroup.defaults.string(forKey: BoardKeys.personName)
    }

    var personId: String { DeviceIdentity.personId }

    var currentBoard: RemoteBoard? {
        boards.first { $0.boardId == currentBoardId }
    }

    var currentBoardName: String {
        currentBoard?.name ?? AppGroup.defaults.string(forKey: BoardKeys.currentBoardName) ?? "my board"
    }

    var boardIds: [String] {
        var seen = Set<String>()
        return ([BoardKeys.personalBoard, currentBoardId] + boards.map(\.boardId)).filter { seen.insert($0).inserted }
    }

    nonisolated static func inviteCode(in url: URL) -> String? {
        guard url.scheme?.lowercased() == "appdemo", url.host()?.lowercased() == "join" else { return nil }
        return url.pathComponents.last { $0 != "/" }
    }

    func start() {
        let me = personId
        guard person != me else { return }
        if person != nil {
            listener?.cancel()
            boards = []
            for key in [BoardKeys.personName, BoardKeys.personalBoardId, BoardKeys.currentBoardId, BoardKeys.currentBoardName, BoardKeys.currentBoardShared] {
                AppGroup.defaults.removeObject(forKey: key)
            }
            personName = nil
            currentBoardId = BoardKeys.currentBoard
            onChange()
        }
        person = me
        Task { await register(me) }
    }

    func show(_ boardId: String) {
        currentBoardId = boardId
        AppGroup.defaults.set(boardId, forKey: BoardKeys.currentBoardId)
        tellTheShareExtension()
        onChange()
    }

    @discardableResult
    func create(named name: String, as personName: String?) async throws -> RemoteBoard {
        try await enter("boards:create", ["boardId": UUID().uuidString.lowercased(), "name": name], as: personName)
    }

    @discardableResult
    func join(code: String, as personName: String?) async throws -> RemoteBoard {
        try await enter("boards:join", ["code": code], as: personName)
    }

    private func enter(_ function: String, _ extra: [String: ConvexEncodable?], as name: String?) async throws -> RemoteBoard {
        let cleaned = name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let newName = cleaned?.isEmpty == false ? cleaned : nil
        var args = extra
        args.updateValue(personId, forKey: "personId")
        args.updateValue(newName ?? personName, forKey: "personName")
        do {
            let board: RemoteBoard = try await convex.mutation(function, with: args)
            if let newName {
                personName = newName
                AppGroup.defaults.set(newName, forKey: BoardKeys.personName)
            }
            if !boards.contains(where: { $0.boardId == board.boardId }) { boards.append(board) }
            show(board.boardId)
            Logger.sync.info("now in the board \(board.name, privacy: .public)")
            return board
        } catch let ClientError.ConvexError(data) {
            throw BoardProblem(message: (try? JSONDecoder().decode(String.self, from: Data(data.utf8))) ?? data)
        }
    }

    private func register(_ me: String) async {
        do {
            let known: RemotePerson = try await convex.mutation("people:upsert", with: [
                "personId": me,
                "personalBoardId": BoardKeys.personalBoard,
                "name": personName,
            ])
            guard person == me else { return }
            AppGroup.defaults.set(known.personalBoardId, forKey: BoardKeys.personalBoardId)
            if personName == nil, known.name != "me" {
                personName = known.name
                AppGroup.defaults.set(known.name, forKey: BoardKeys.personName)
            }
            if AppGroup.defaults.string(forKey: BoardKeys.currentBoardId) == nil {
                currentBoardId = known.personalBoardId
            }
            onChange()
        } catch {
            Logger.sync.error("couldn't register this person with the backend: \(String(describing: error), privacy: .public)")
        }
        guard person == me else { return }
        listen(as: me)
    }

    private func listen(as me: String) {
        listener = convex.subscribe(to: "boards:mine", with: ["personId": me], yielding: [RemoteBoard].self)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                MainActor.assumeIsolated {
                    if case let .failure(error) = completion {
                        Logger.sync.error("the list of boards stopped updating: \(String(describing: error), privacy: .public)")
                    }
                    Task { [weak self] in
                        try? await Task.sleep(for: .seconds(8))
                        guard let self, self.person == me else { return }
                        self.listen(as: me)
                    }
                }
            }, receiveValue: { [weak self] list in
                MainActor.assumeIsolated {
                    self?.take(list, for: me)
                }
            })
    }

    private func take(_ list: [RemoteBoard], for me: String) {
        guard person == me else { return }
        boards = list
        var wanted = list.contains { $0.boardId == currentBoardId } ? currentBoardId : (list.first?.boardId ?? currentBoardId)
        #if DEBUG
        if me.hasPrefix("seed-"), AppGroup.defaults.string(forKey: BoardKeys.currentBoardId) == nil,
           let shared = list.first(where: \.shared) {
            wanted = shared.boardId
            AppGroup.defaults.set(wanted, forKey: BoardKeys.currentBoardId)
        }
        #endif
        currentBoardId = wanted
        tellTheShareExtension()
        onChange()
    }

    private func tellTheShareExtension() {
        guard let board = currentBoard else { return }
        AppGroup.defaults.set(board.name, forKey: BoardKeys.currentBoardName)
        AppGroup.defaults.set(board.shared, forKey: BoardKeys.currentBoardShared)
    }
}
