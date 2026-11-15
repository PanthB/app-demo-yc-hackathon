import Foundation

enum SeenBoard {
    private static let key = "seenZones"

    static func load(from defaults: UserDefaults = .standard) -> [UUID: Zone] {
        guard let stored = defaults.dictionary(forKey: key) as? [String: String] else { return [:] }
        var zones: [UUID: Zone] = [:]
        for (id, raw) in stored {
            if let uuid = UUID(uuidString: id), let zone = Zone(rawValue: raw) {
                zones[uuid] = zone
            }
        }
        return zones
    }

    static func save(_ zones: [UUID: Zone], to defaults: UserDefaults = .standard) {
        defaults.set(Dictionary(uniqueKeysWithValues: zones.map { ($0.key.uuidString, $0.value.rawValue) }), forKey: key)
    }
}
