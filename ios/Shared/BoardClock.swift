import Foundation
import Observation

@Observable
final class BoardClock {
    private(set) var now: Date

    init() {
        now = Self.read()
    }

    func tick() {
        now = Self.read()
    }

    private static func read() -> Date {
        #if DEBUG
        if let text = UserDefaults.standard.string(forKey: "BoardDebugNow"),
           let date = ISO8601DateFormatter().date(from: text) {
            return date
        }
        #endif
        return .now
    }
}
