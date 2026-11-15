import Foundation

enum BoardKeys {
    static let personName = "personName"
    static let personalBoardId = "personalBoardId"
    static let currentBoardId = "currentBoardId"
    static let currentBoardName = "currentBoardName"
    static let currentBoardShared = "currentBoardShared"

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
