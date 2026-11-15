import Foundation

enum ViewMode: String, CaseIterable, Sendable {
    case list, cards, board, night

    static let storageKey = "viewMode"
    static let urlScheme = "appdemo"

    static func resolve(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        stored: String?
    ) -> ViewMode {
        if let flag = arguments.firstIndex(of: "-view"),
           arguments.indices.contains(flag + 1),
           let mode = ViewMode(rawValue: arguments[flag + 1]) {
            return mode
        }
        return ViewMode(stored: stored)
    }

    init(stored: String?) {
        self = stored.flatMap(ViewMode.init(rawValue:)) ?? .night
    }

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.urlScheme,
              url.host()?.lowercased() == "view",
              let mode = ViewMode(rawValue: url.lastPathComponent.lowercased())
        else { return nil }
        self = mode
    }

    var symbol: String {
        switch self {
        case .list: "list.bullet"
        case .cards: "square.grid.2x2"
        case .board: "rectangle.on.rectangle.angled"
        case .night: "moon"
        }
    }
}
