import Foundation
import os

enum AppGroup {
    static let identifier: String = {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_ID") as? String, !id.isEmpty else {
            Logger.store.fault("APP_GROUP_ID is missing from Info.plist; set it in Config/AppDemo.xcconfig")
            return ""
        }
        return id
    }()

    static let containerURL: URL? = {
        guard !identifier.isEmpty,
              let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        else {
            Logger.store.fault("app group \(identifier, privacy: .public) did not resolve; check the entitlements")
            return nil
        }
        return url
    }()

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

extension Inbox {
    static let shared: Inbox? = AppGroup.containerURL.map {
        Inbox(root: $0.appending(path: "inbox", directoryHint: .isDirectory))
    }
}

enum DeviceIdentity {
    static var personId: String { storedId(for: "personId") }
    static var boardId: String { storedId(for: "boardId") }

    private static func storedId(for key: String) -> String {
        if let existing = AppGroup.defaults.string(forKey: key) {
            return existing
        }
        let created = UUID().uuidString.lowercased()
        AppGroup.defaults.set(created, forKey: key)
        return created
    }
}
