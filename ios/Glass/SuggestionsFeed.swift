import Combine
import ConvexMobile
import Observation
import os
import SwiftData
import SwiftUI

extension Logger {
    static let suggestions = Logger(subsystem: subsystem, category: "suggestions")
}

@MainActor
@Observable
final class SuggestionsModel {
    private struct Prefs: Decodable {
        var recsMedia: Bool
        var recsEvents: Bool
    }

    private(set) var groups: [FeedGroup]?
    private(set) var hidden: Set<String> = []
    private(set) var problem: String?

    @ObservationIgnored private var listener: AnyCancellable?
    @ObservationIgnored private var retry: Task<Void, Never>?
    @ObservationIgnored private var following: (boardId: String, personId: String)?

    static let sample: String? = {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "BoardDebugSuggestionsSample")
        #else
        return nil
        #endif
    }()

    static let keepsWritesLocal: Bool = {
        #if DEBUG
        return sample != nil || UserDefaults.standard.bool(forKey: "BoardDebugSeed")
        #else
        return false
        #endif
    }()

    func follow(boardId: String, personId: String) {
        stop()
        groups = nil
        hidden = []
        problem = nil
        #if DEBUG
        if let sample = Self.sample {
            groups = FeedGroup.sample(sample)
            return
        }
        #endif
        following = (boardId, personId)
        listen()
    }

    func stop() {
        retry?.cancel()
        listener?.cancel()
        listener = nil
        following = nil
    }

    func save(_ suggestion: FeedSuggestion, as personId: String) {
        send("suggestions:save", ["id": suggestion.id, "personId": personId], hiding: suggestion.id)
    }

    func dismiss(_ suggestion: FeedSuggestion) {
        send("suggestions:dismiss", ["id": suggestion.id], hiding: suggestion.id)
    }

    func prefs(for personId: String, media: Bool? = nil, events: Bool? = nil) async -> (media: Bool, events: Bool)? {
        guard !Self.keepsWritesLocal else { return nil }
        do {
            let saved: Prefs = try await convex.mutation("people:setPrefs", with: ["personId": personId, "recsMedia": media, "recsEvents": events])
            return (saved.recsMedia, saved.recsEvents)
        } catch {
            Logger.suggestions.error("people:setPrefs didn't reach the backend: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private func send(_ function: String, _ args: [String: ConvexEncodable?], hiding id: String) {
        problem = nil
        hidden.insert(id)
        guard !Self.keepsWritesLocal else { return }
        Task {
            do {
                try await convex.mutation(function, with: args)
            } catch {
                Logger.suggestions.error("\(function, privacy: .public) didn't reach the backend for \(id, privacy: .public): \(String(describing: error), privacy: .public)")
                hidden.remove(id)
                problem = "that didn't go through. try again in a moment."
            }
        }
    }

    private func listen() {
        guard let following else { return }
        let boardId = following.boardId
        listener = convex.subscribe(to: "suggestions:list", with: ["boardId": boardId, "personId": following.personId], yielding: LossyList<FeedGroup>.self)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                MainActor.assumeIsolated {
                    if case let .failure(error) = completion {
                        Logger.suggestions.error("suggestions for \(boardId, privacy: .public) stopped updating: \(String(describing: error), privacy: .public)")
                    }
                    self?.listenAgainSoon(boardId)
                }
            }, receiveValue: { [weak self] list in
                MainActor.assumeIsolated {
                    guard let self, self.following?.boardId == boardId else { return }
                    if list.skipped > 0 {
                        Logger.suggestions.error("\(list.skipped) clusters of suggestions in \(boardId, privacy: .public) couldn't be read and were left out")
                    }
                    self.groups = list.elements
                    self.problem = nil
                }
            })
    }

    private func listenAgainSoon(_ boardId: String) {
        guard following?.boardId == boardId else { return }
        if groups == nil {
            problem = "i can't reach the suggestions right now. i'll keep trying."
        }
        retry?.cancel()
        retry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, let self, self.following?.boardId == boardId else { return }
            self.listen()
        }
    }
}

struct SuggestionsFeed: View {
    let boardId: String

    @Environment(BoardsStore.self) private var boards
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var drops: [Drop]
    @AppStorage("recsMedia") private var media = true
    @AppStorage("recsEvents") private var events = true
    @State private var model = SuggestionsModel()
    @State private var saves = 0
    @State private var note: String?

    private var groups: [FeedGroup] {
        guard media || events else { return [] }
        return (model.groups ?? []).compactMap { group in
            var group = group
            group.suggestions = group.suggestions.filter { !model.hidden.contains($0.id) && ($0.isMedia ? media : events) }
            return group.suggestions.isEmpty && !group.searching ? nil : group
        }
    }

    private var shared: Bool {
        (boardId == boards.currentBoardId ? boards.currentBoard?.shared : nil) ?? (boardId != BoardKeys.personalBoard)
    }

    var body: some View {
        let groups = groups
        let known = Dictionary(drops.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let problem = model.problem, model.groups != nil {
                    Text(problem).font(.footnote).foregroundStyle(.secondary).padding(.top, 12)
                }
                ForEach(groups) { group in
                    header(group)
                    ForEach(group.suggestions) { suggestion in
                        SuggestionCard(suggestion: suggestion, drops: known) {
                            saves += 1
                            note = "saved to \(boards.boards.first { $0.boardId == boardId }?.name ?? "the board")."
                            model.save(suggestion, as: boards.personId)
                        } dismiss: {
                            model.dismiss(suggestion)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .animation(reduceMotion ? nil : .smooth, value: groups)
        }
        .scrollEdgeEffectStyle(.hard, for: .top)
        .background(Color(.systemGroupedBackground))
        .overlay {
            if !media, !events {
                ContentUnavailableView {
                    Label("recommendations are off.", systemImage: "slider.horizontal.3")
                } description: {
                    Text("you can turn them back on here anytime.")
                } actions: {
                    Button("turn them back on") {
                        media = true
                        events = true
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("recsBackOn")
                }
            } else if model.groups == nil {
                if let problem = model.problem {
                    ContentUnavailableView {
                        Label("nothing to show yet.", systemImage: "wifi.slash")
                    } description: {
                        Text(problem)
                    }
                } else {
                    ProgressView()
                }
            } else if groups.isEmpty {
                ContentUnavailableView {
                    Label("nothing yet.", systemImage: "binoculars")
                } description: {
                    Text("add a few things and i'll look for stuff for \(shared ? "y'all" : "you").")
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let note {
                Text(note)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 12)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                    .accessibilityIdentifier("suggestionSaved")
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: note)
        .task(id: saves) {
            guard let said = note else { return }
            AccessibilityNotification.Announcement(said).post()
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            note = nil
        }
        .navigationTitle("suggestions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("what to look for") {
                        Toggle("songs, clips and shows", isOn: $media)
                        Toggle("events and places nearby", isOn: $events)
                    }
                    .menuActionDismissBehavior(.disabled)
                } label: {
                    Label("what to look for", systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("recsMenu")
            }
        }
        .sensoryFeedback(.success, trigger: saves)
        .task(id: boardId) {
            model.follow(boardId: boardId, personId: boards.personId)
            if let saved = await model.prefs(for: boards.personId) {
                media = saved.media
                events = saved.events
            }
        }
        .onChange(of: media) { _, on in
            Task { await model.prefs(for: boards.personId, media: on) }
        }
        .onChange(of: events) { _, on in
            Task { await model.prefs(for: boards.personId, events: on) }
        }
        .onDisappear { model.stop() }
    }

    @ViewBuilder
    private func header(_ group: FeedGroup) -> some View {
        if group.suggestions.isEmpty {
            looking("looking for things that fit \(group.clusterLabel).")
                .padding(.top, 12)
                .accessibilityIdentifier("cluster-\(group.clusterId)")
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.clusterLabel).font(.title3.weight(.semibold))
                if group.searching {
                    looking("looking for more.")
                }
            }
            .padding(.top, 12)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("cluster-\(group.clusterId)")
        }
    }

    private func looking(_ words: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small).tint(.secondary)
            Text(words).font(.footnote).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
