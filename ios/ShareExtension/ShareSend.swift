import Foundation
import os

enum ShareSend {
    static func send(_ items: [InboxItem], boardId: String?) async {
        guard let deployment = AppGroup.defaults.string(forKey: "convexURL"),
              let url = URL(string: "\(deployment)/api/mutation")
        else { return }
        let board = boardId ?? AppGroup.defaults.string(forKey: "personalBoardId") ?? DeviceIdentity.boardId
        let limits = URLSessionConfiguration.ephemeral
        limits.timeoutIntervalForRequest = 2
        limits.timeoutIntervalForResource = 2
        let session = URLSession(configuration: limits)
        for item in items {
            guard let args = arguments(for: item, boardId: board, personId: DeviceIdentity.personId) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                let body: [String: Any] = ["path": "drops:submit", "args": args, "format": "json"]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (data, _) = try await session.data(for: request)
                let answer = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if answer?["status"] as? String == "success" {
                    Logger.share.info("sent \(item.id.uuidString, privacy: .public) to the board from the share sheet")
                } else {
                    Logger.share.error("the backend didn't take \(item.id.uuidString, privacy: .public) from the share sheet, so the app sends it when it opens: \(answer?["errorMessage"] as? String ?? "no reason given", privacy: .public)")
                }
            } catch {
                Logger.share.error("couldn't send \(item.id.uuidString, privacy: .public) from the share sheet, so the app sends it when it opens: \(String(describing: error), privacy: .public)")
            }
        }
    }

    static func arguments(for item: InboxItem, boardId: String, personId: String, timeZone: TimeZone = .current) -> [String: Any]? {
        guard item.kind == .url, item.files.isEmpty, let link = item.url, !LinkReading.isShortMapsLink(link) else { return nil }
        let seen = LinkReading.read(link, caption: item.text)
        guard seen.placeSearch == nil else { return nil }

        var hints: [String: Any] = [:]
        if let title = seen.title ?? seen.placeName ?? LinkReading.firstLine(of: item.text) { hints["linkTitle"] = title }
        if let artist = seen.artist { hints["artist"] = artist }
        if let place = seen.placeName { hints["placeName"] = place }

        var args: [String: Any] = [
            "boardId": boardId,
            "personId": personId,
            "clientId": item.id.uuidString,
            "kind": item.kind.rawValue,
            "url": link,
            "capturedAt": item.createdAt.timeIntervalSince1970 * 1000,
            "utcOffsetMinutes": Double(timeZone.secondsFromGMT(for: item.createdAt)) / 60,
        ]
        if let text = item.text { args["text"] = text }
        if let latitude = seen.latitude, let longitude = seen.longitude {
            args["latitude"] = latitude
            args["longitude"] = longitude
        }
        if !hints.isEmpty { args["hints"] = hints }
        return args
    }
}
