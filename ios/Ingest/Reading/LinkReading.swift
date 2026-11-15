import Foundation

enum LinkReading {
    struct Seen: Equatable {
        var title: String?
        var artist: String?
        var placeName: String?
        var latitude: Double?
        var longitude: Double?
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
        var spot: String?
        if host == "maps.apple.com" {
            seen.placeName = query["name"] ?? query["q"]
            spot = query["coordinate"] ?? query["ll"]
        } else if host.hasPrefix("maps.google.") || ((host == "google.com" || host.hasPrefix("www.google.")) && path.first == "maps") {
            let named = path.firstIndex(of: "place").flatMap { path.indices.contains($0 + 1) ? path[$0 + 1] : nil } ?? query["q"]
            seen.placeName = named?.replacingOccurrences(of: "+", with: " ")
            spot = path.first { $0.hasPrefix("@") }.map { String($0.dropFirst()) }
        }
        let numbers = (spot ?? "").split(separator: ",").prefix(2).compactMap { Double($0) }
        if numbers.count == 2, abs(numbers[0]) <= 90, abs(numbers[1]) <= 180 {
            seen.latitude = numbers[0]
            seen.longitude = numbers[1]
        }
        return seen
    }
}
