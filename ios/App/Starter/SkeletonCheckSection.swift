#if DEBUG
import os
import SwiftData
import SwiftUI

struct SkeletonCheckSection: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Drop.createdAt, order: .reverse) private var drops: [Drop]
    @State private var inboxItems: [InboxItem] = []

    var body: some View {
        Section("skeleton check") {
            LabeledContent("app group", value: AppGroup.containerURL == nil ? "missing" : "ok")
                .accessibilityIdentifier("appGroupStatus")
            LabeledContent("inbox", value: "\(inboxItems.count) waiting")
                .accessibilityIdentifier("inboxStatus")
            ForEach(inboxItems) { item in
                Text("\(item.kind.rawValue): \(item.url ?? item.text ?? "")")
                    .font(.footnote)
                    .lineLimit(2)
            }
            LabeledContent("board store", value: "\(drops.count) drops")
                .accessibilityIdentifier("storeStatus")
            if let latest = drops.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text(latest.rawText ?? "")
                    Text("\(latest.whenLabel ?? "no time") · \(latest.zone.rawValue) · \(latest.objectKind.rawValue)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let dueAt = latest.dueAt {
                        Text(timerInterval: Date.now...max(dueAt, .now), countsDown: true)
                            .font(.footnote.monospacedDigit())
                    }
                }
            }
            Button("add a test drop that says remind me in 1 hr") {
                addTestDrop()
            }
            .accessibilityIdentifier("addTestDrop")
        }
        .onAppear(perform: refreshInbox)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshInbox() }
        }
    }

    private func refreshInbox() {
        inboxItems = Inbox.shared?.pending() ?? []
    }

    private func addTestDrop() {
        let text = "remind me in 1 hr"
        let drop = Drop(dropperId: DeviceIdentity.personId, sourceKind: .text, rawText: text)
        if let parsed = TimeWords.parse(text) {
            drop.dueAt = parsed.dueAt
            drop.startsAt = parsed.startsAt
            drop.whenLabel = parsed.whenLabel
            drop.applyDecidedZone(parsed.zone, unsure: false)
        }
        context.insert(drop)
        do {
            try context.save()
        } catch {
            Logger.store.error("saving the test drop failed: \(String(describing: error), privacy: .public)")
        }
    }
}
#endif
