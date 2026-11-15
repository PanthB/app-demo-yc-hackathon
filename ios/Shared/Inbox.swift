import Foundation

struct InboxItem: Codable, Identifiable, Equatable, Sendable {
    var version = 1
    var id: UUID
    var createdAt: Date
    var kind: SourceKind
    var text: String?
    var url: String?
    var files: [String] = []
    var latitude: Double?
    var longitude: Double?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        kind: SourceKind,
        text: String? = nil,
        url: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.text = text
        self.url = url
        self.latitude = latitude
        self.longitude = longitude
    }
}

enum InboxPayload: Sendable {
    case data(Data, name: String)
    case file(URL, name: String)
}

struct Inbox: Sendable {
    let root: URL

    func folder(for id: UUID) -> URL {
        root.appending(path: id.uuidString, directoryHint: .isDirectory)
    }

    func fileURL(_ name: String, in item: InboxItem) -> URL {
        folder(for: item.id).appending(path: name)
    }

    @discardableResult
    func write(_ item: InboxItem, payloads: [InboxPayload] = []) throws -> InboxItem {
        let fileManager = FileManager.default
        let staging = root
            .appending(path: ".staging", directoryHint: .isDirectory)
            .appending(path: item.id.uuidString, directoryHint: .isDirectory)
        try? fileManager.removeItem(at: staging)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)

        var written = item
        written.files = []
        for payload in payloads {
            switch payload {
            case let .data(data, name):
                let safeName = URL(fileURLWithPath: name).lastPathComponent
                try data.write(to: staging.appending(path: safeName))
                written.files.append(safeName)
            case let .file(source, name):
                let safeName = URL(fileURLWithPath: name).lastPathComponent
                try fileManager.copyItem(at: source, to: staging.appending(path: safeName))
                written.files.append(safeName)
            }
        }
        try Self.encoder.encode(written).write(to: staging.appending(path: "drop.json"))

        let destination = folder(for: item.id)
        try? fileManager.removeItem(at: destination)
        try fileManager.moveItem(at: staging, to: destination)
        return written
    }

    func pending() -> [InboxItem] {
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return folders
            .compactMap { folder in
                guard let data = try? Data(contentsOf: folder.appending(path: "drop.json")) else { return nil }
                return try? Self.decoder.decode(InboxItem.self, from: data)
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func remove(_ id: UUID) throws {
        try FileManager.default.removeItem(at: folder(for: id))
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}
