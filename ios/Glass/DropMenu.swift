import SwiftData
import SwiftUI
import UIKit

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
        if drop.remoteId != nil, !drop.isArriving {
            Menu("group", systemImage: "rectangle.3.group") {
                GroupMenu(drop: drop)
            }
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

struct GroupMenu: View {
    let drop: Drop
    @Query(sort: \Drop.createdAt, order: .reverse) private var allDrops: [Drop]
    @Environment(BoardSync.self) private var sync

    var body: some View {
        let groups = DropGroups.choices(for: drop, among: allDrops)
        ForEach(groups) { group in
            Button(group.label) { sync.setKind(drop, group.kind) }
        }
        if !groups.isEmpty {
            Divider()
        }
        Button("new group…", systemImage: "plus") {
            GroupNamePrompt.ask { sync.setKind(drop, $0) }
        }
    }
}

struct DropGroupChoice: Identifiable, Equatable {
    let id: String
    let label: String
    let kind: String
}

enum DropGroups {
    static let notKinds: Set<String> = [
        "dreamy", "cozy", "upbeat", "moody", "wild", "calm",
        "morning", "golden hour", "late night",
        "outdoors", "by the water", "food", "live music", "at home",
        "mission", "castro", "haight", "hayes valley", "nopa", "north beach", "chinatown", "japantown", "marina", "presidio",
        "golden gate park", "sunset", "richmond", "soma", "embarcadero", "dogpatch", "noe valley", "lands end", "tenderloin", "union square",
        "pop", "indie", "rock", "hip hop", "r&b", "electronic", "jazz", "folk", "country", "soul", "classical",
        "slow", "steady", "high energy",
    ]

    static func kind(of drop: Drop) -> String? {
        drop.vibes.first.flatMap { notKinds.contains($0) ? nil : $0 }
    }

    static func choices(for drop: Drop, among drops: [Drop]) -> [DropGroupChoice] {
        let own = kind(of: drop)
        let others = drops.filter { $0.boardId == drop.boardId && $0.clusterId != nil && $0.clusterId != drop.clusterId && !$0.isArriving }
        var taken: Set<String> = []
        return Dictionary(grouping: others) { $0.clusterId ?? "" }
            .compactMap { id, members -> (choice: DropGroupChoice, size: Int)? in
                let counts = Dictionary(grouping: members.compactMap(kind(of:))) { $0 }.mapValues(\.count)
                guard let target = counts.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key })?.key, target != own else { return nil }
                let label = members.max { $0.createdAt < $1.createdAt }?.clusterLabel ?? target
                return (DropGroupChoice(id: id, label: label, kind: target), members.count)
            }
            .sorted { $0.size != $1.size ? $0.size > $1.size : $0.choice.label < $1.choice.label }
            .map(\.choice)
            .filter { taken.insert($0.kind).inserted }
    }

    static func name(_ typed: String) -> String? {
        let words = typed.lowercased()
            .filter { ($0.isASCII && ($0.isLetter || $0.isNumber)) || " &'-".contains($0) }
            .split(whereSeparator: \.isWhitespace)
        guard (1...3).contains(words.count) else { return nil }
        let name = words.joined(separator: " ")
        return name.count <= 24 && !notKinds.contains(name) ? name : nil
    }
}

@MainActor
enum GroupNamePrompt {
    static func ask(_ done: @escaping (String) -> Void) {
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
            var top = scene?.keyWindow?.rootViewController
            while let next = top?.presentedViewController, !next.isBeingDismissed { top = next }
            guard let top else { return }
            let alert = UIAlertController(title: "new group", message: "name it in up to 3 words.", preferredStyle: .alert)
            let make = UIAlertAction(title: "make it", style: .default) { [weak alert] _ in
                if let name = DropGroups.name(alert?.textFields?.first?.text ?? "") { done(name) }
            }
            make.isEnabled = false
            alert.addTextField { field in
                field.placeholder = "ceramics classes"
                field.autocapitalizationType = .none
                field.accessibilityIdentifier = "groupName"
                field.addAction(UIAction { [weak field] _ in make.isEnabled = DropGroups.name(field?.text ?? "") != nil }, for: .editingChanged)
            }
            alert.addAction(UIAlertAction(title: "cancel", style: .cancel))
            alert.addAction(make)
            alert.preferredAction = make
            top.present(alert, animated: true)
        }
    }
}
