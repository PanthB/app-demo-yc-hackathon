import Foundation
import os
import SwiftData

enum BoardStore {
    static let schema = Schema([Drop.self])

    static func makeContainer() -> ModelContainer {
        do {
            guard let url = AppGroup.containerURL?.appending(path: "Board.store") else {
                Logger.store.fault("app group is missing, so the board store lives in the app's own container and the share extension can't see it")
                return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema))
            }
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
        } catch {
            Logger.store.fault("board store failed to open, falling back to memory: \(String(describing: error), privacy: .public)")
            return makeInMemoryContainer()
        }
    }

    static func makeInMemoryContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        } catch {
            Logger.store.fault("in-memory board store failed to open: \(String(describing: error), privacy: .public)")
            fatalError("in-memory board store failed to open: \(error)")
        }
    }
}
