import Foundation

enum BoardKeys {
    static let personName = "personName"
    static let personalBoardId = "personalBoardId"
    static let currentBoardId = "currentBoardId"
    static let currentBoardName = "currentBoardName"
    static let currentBoardShared = "currentBoardShared"
    static let person = "boardsPerson"

    static func keep(for personId: String) {
        guard AppGroup.defaults.string(forKey: person) != personId else { return }
        for key in [personName, personalBoardId, currentBoardId, currentBoardName, currentBoardShared] {
            AppGroup.defaults.removeObject(forKey: key)
        }
        AppGroup.defaults.set(personId, forKey: person)
    }

    static func inboxBoard(_ id: UUID) -> String {
        "inboxBoard.\(id.uuidString)"
    }

    static var personalBoard: String {
        AppGroup.defaults.string(forKey: personalBoardId) ?? DeviceIdentity.boardId
    }

    static var currentBoard: String {
        AppGroup.defaults.string(forKey: currentBoardId) ?? personalBoard
    }
}
