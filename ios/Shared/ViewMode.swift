import Foundation

enum ViewMode: String, CaseIterable, Sendable {
    case list, cards, board

    static let storageKey = "view"
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
        return stored.flatMap(ViewMode.init(rawValue:)) ?? .cards
    }

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.urlScheme,
              url.host()?.lowercased() == "view",
              let mode = ViewMode(rawValue: url.lastPathComponent.lowercased())
        else { return nil }
        self = mode
    }
}
