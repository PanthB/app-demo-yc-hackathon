import SwiftUI

struct DropMenu: View {
    let drop: Drop
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dropActions) private var actions

    var body: some View {
        Button(drop.isPinned ? "unpin" : "pin", systemImage: drop.isPinned ? "pin.slash" : "pin") {
            withAnimation(reduceMotion ? nil : .smooth) { actions.pin(drop, !drop.isPinned) }
        }
        if drop.zone != .done {
            Button("mark done", systemImage: "checkmark.circle") {
                withAnimation(reduceMotion ? nil : .smooth) { actions.done(drop) }
            }
        }
        if drop.canUndoMove {
            Button("put it back", systemImage: "arrow.uturn.backward") {
                withAnimation(reduceMotion ? nil : .smooth) { actions.undo(drop) }
            }
        }
        Menu("move to", systemImage: "arrow.right") {
            ZoneMenu(drop: drop)
        }
        if drop.url != nil {
            Button("open link", systemImage: "arrow.up.right") {
                actions.open(drop)
            }
        }
    }
}

struct ZoneMenu: View {
    let drop: Drop
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dropActions) private var actions
    @Environment(BoardClock.self) private var clock

    var body: some View {
        ForEach(Zone.moveTargets(from: drop.boardZone(now: clock.now)), id: \.self) { zone in
            Button(zone.displayName) {
                withAnimation(reduceMotion ? nil : .smooth) { actions.move(drop, zone) }
            }
        }
    }
}
