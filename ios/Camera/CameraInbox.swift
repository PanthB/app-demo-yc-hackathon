import Foundation
import os

enum CameraInbox {
    @discardableResult
    static func drop(_ data: Data, into inbox: Inbox? = .shared, takenAt date: Date = .now) -> InboxItem? {
        guard let inbox else {
            Logger.camera.fault("app group is missing, so the photo can't reach the board")
            return nil
        }
        do {
            let written = try inbox.write(InboxItem(createdAt: date, kind: .image), payloads: [.data(data, name: "photo.jpg")])
            Logger.camera.info("dropped a camera photo as \(written.id.uuidString, privacy: .public)")
            return written
        } catch {
            Logger.camera.error("couldn't drop the camera photo: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
