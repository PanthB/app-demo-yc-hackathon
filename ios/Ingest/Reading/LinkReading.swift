import Foundation
import os

enum LinkReading {
    struct Seen: Equatable {
        var title: String?
        var artist: String?
        var placeName: String?
        var latitude: Double?
        var longitude: Double?
        var placeSearch: String?
    }

    static func firstLine(of caption: String?) -> String? {
        let siteName = #/\s+[|•·–—-]\s+(spotify|apple music|tiktok|instagram|youtube|google maps|apple maps)\s*$/#.ignoresCase()
        let marks = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{200E}\u{200F}"))
        guard let line = caption?.split(whereSeparator: \.isNewline).first else { return nil }
        let cleaned = line.trimmingCharacters(in: marks).replacing(siteName, with: "").trimmingCharacters(in: marks)
        return cleaned.isEmpty ? nil : cleaned
    }

    static func read(_ link: String, caption: String?) -> Seen {
        var seen = Seen()
        guard let parts = URLComponents(string: link), let host = parts.host?.lowercased() else { return seen }

        if host.hasSuffix("spotify.com") || host == "spotify.link" || host == "music.apple.com" {
            let songBy = #/^(?<title>.+?)\s+[–—-]\s+(song and lyrics|song|single|album|ep)\s+by\s+(?<artist>.+)$/#.ignoresCase()
            if let song = firstLine(of: caption)?.wholeMatch(of: songBy) {
                seen.title = String(song.title)
                seen.artist = String(song.artist)
            }
            return seen
        }

        let query = Dictionary(
            (parts.queryItems ?? []).compactMap { item in item.value.map { (item.name, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        let path = parts.path.split(separator: "/").map(String.init)
        var named: String?
        var spot: String?
        if host == "maps.apple.com" {
            seen.placeName = query["name"] ?? query["q"]
            named = [seen.placeName, query["address"]].compactMap { $0 }.joined(separator: ", ")
            spot = query["coordinate"] ?? query["ll"]
        } else if host.hasPrefix("maps.google.") || ((host == "google.com" || host.hasPrefix("www.google.")) && path.first == "maps") {
            guard !path.contains("dir") else { return seen }
            let after = path.firstIndex { $0 == "place" || $0 == "search" }.flatMap { path.indices.contains($0 + 1) ? path[$0 + 1] : nil }
            named = (after.flatMap { $0.hasPrefix("@") || $0.hasPrefix("data=") ? nil : $0 } ?? query["q"] ?? query["query"])?
                .replacingOccurrences(of: "+", with: " ")
            let pin = link.firstMatch(of: #/!3d(-?[0-9.]+)!4d(-?[0-9.]+)/#).map { "\($0.1),\($0.2)" }
            spot = pin ?? path.first { $0.hasPrefix("@") }.map { String($0.dropFirst()) } ?? query["ll"]
            if coordinate(in: named) != nil {
                spot = spot ?? named
                named = nil
            }
            seen.placeName = named?.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) }
        }
        if seen.placeName?.isEmpty == true { seen.placeName = nil }
        if let found = coordinate(in: spot) {
            seen.latitude = found.latitude
            seen.longitude = found.longitude
        } else if seen.placeName != nil {
            seen.placeSearch = named
        }
        return seen
    }

    static func isShortMapsLink(_ link: String) -> Bool {
        guard let parts = URLComponents(string: link), let host = parts.host?.lowercased() else { return false }
        return host == "maps.app.goo.gl" || (host == "goo.gl" && parts.path.hasPrefix("/maps"))
    }

    static func destination(of link: String) async -> String? {
        guard let url = URL(string: link) else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "HEAD"
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return response.url?.absoluteString
        } catch {
            Logger.ingest.error("couldn't follow \(url.host() ?? "a short link", privacy: .public) to the place it points at: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private static func coordinate(in text: String?) -> (latitude: Double, longitude: Double)? {
        let numbers = (text ?? "").split(separator: ",").prefix(2).compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard numbers.count == 2, abs(numbers[0]) <= 90, abs(numbers[1]) <= 180 else { return nil }
        return (numbers[0], numbers[1])
    }
}
