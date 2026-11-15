import os
import SwiftUI

struct DropActions {
    var pin: @MainActor (Drop, Bool) -> Void = { $0.setPinned($1) }
    var move: @MainActor (Drop, Zone) -> Void = { $0.moveByUser(to: $1) }
    var done: @MainActor (Drop) -> Void = { $0.moveByUser(to: .done) }
    var undo: @MainActor (Drop) -> Void = { $0.undoMove() }
    var open: @MainActor (Drop) -> Void = { _ in
        Logger.app.error("open was called before RootView installed the drop actions")
    }
}

extension EnvironmentValues {
    @Entry var dropActions = DropActions()
}
