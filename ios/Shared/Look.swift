import Foundation

enum Look: String, CaseIterable, Sendable {
    case paper, glass

    static let storageKey = "look"
    static let urlScheme = "appdemo"

    static func resolve(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        stored: String?
    ) -> Look {
        if let flag = arguments.firstIndex(of: "-look"),
           arguments.indices.contains(flag + 1),
           let look = Look(rawValue: arguments[flag + 1]) {
            return look
        }
        return stored.flatMap(Look.init(rawValue:)) ?? .paper
    }

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.urlScheme,
              url.host()?.lowercased() == "look",
              let look = Look(rawValue: url.lastPathComponent.lowercased())
        else { return nil }
        self = look
    }
}
