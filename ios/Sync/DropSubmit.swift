import ConvexMobile
import Foundation

enum DropSubmit {
    @MainActor
    static func arguments(
        for drop: Drop,
        reading: DropReading,
        boardId: String,
        personId: String,
        timeZone: TimeZone = .current
    ) -> [String: ConvexEncodable?] {
        var hints: [String: ConvexEncodable?] = [:]
        if drop.sourceKind == .url {
            if let title = drop.title ?? LinkReading.firstLine(of: drop.rawText) { hints["linkTitle"] = title }
            if let place = drop.placeName { hints["placeName"] = place }
        }
        if let artist = drop.artist { hints["artist"] = artist }
        if let transcript = reading.transcript { hints["transcript"] = transcript }
        if let pdfText = reading.pdfText { hints["pdfText"] = pdfText }
        if let dueAt = drop.dueAt { hints["dueAt"] = dueAt.convexTime }
        let hintsValue: ConvexEncodable? = hints.isEmpty ? nil : hints

        let images: [ConvexEncodable?] = reading.storageIds.prefix(4).map { $0 }
        let imagesValue: ConvexEncodable? = images.isEmpty ? nil : images

        return [
            "boardId": boardId,
            "personId": personId,
            "clientId": drop.id.uuidString,
            "kind": drop.sourceKindRaw,
            "text": drop.rawText,
            "url": drop.url,
            "imageIds": imagesValue,
            "capturedAt": drop.createdAt.convexTime,
            "utcOffsetMinutes": Double(timeZone.secondsFromGMT(for: drop.createdAt)) / 60,
            "latitude": drop.anchorLatitude ?? drop.latitude,
            "longitude": drop.anchorLongitude ?? drop.longitude,
            "hints": hintsValue,
        ]
    }
}

enum Uploads {
    private struct Stored: Decodable {
        var storageId: String
    }

    static func send(_ file: URL) async throws -> String {
        let target: String = try await convex.mutation("files:generateUploadUrl")
        guard let url = URL(string: target) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(file.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: file)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(Stored.self, from: data).storageId
    }
}
