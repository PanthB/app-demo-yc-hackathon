import SwiftUI

struct SettingsButton: View {
    @State private var showsSettings = false

    var body: some View {
        Button("views") { showsSettings = true }
            .accessibilityHint("opens settings")
            .accessibilityIdentifier("settingsButton")
            .sheet(isPresented: $showsSettings) { SettingsSheet() }
    }
}

struct SettingsSheet: View {
    @AppStorage(ViewMode.storageKey) private var storedView: String?
    @AppStorage(Mood.handwritingKey) private var handwriting = true
    @AppStorage(Mood.linesKey) private var lines = false
    @AppStorage("recsMedia") private var media = true
    @AppStorage("recsEvents") private var events = true
    @Environment(BoardsStore.self) private var boards
    @Environment(\.dismiss) private var dismiss
    @State private var suggestions = SuggestionsModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("theme") {
                    Picker("theme", selection: Binding(
                        get: { ViewMode(stored: storedView) == .board ? ViewMode.board : .night },
                        set: { mode in
                            dismiss()
                            storedView = mode.rawValue
                        }
                    )) {
                        Text("night").tag(ViewMode.night)
                        Text("scrapbook").tag(ViewMode.board)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .accessibilityIdentifier("themePicker")
                }
                Section("scrapbook") {
                    Toggle("handwriting", isOn: $handwriting)
                    Toggle("lines", isOn: $lines)
                }
                Section("suggestions") {
                    Toggle("songs, clips and shows", isOn: $media)
                    Toggle("events and places nearby", isOn: $events)
                }
            }
            .textCase(nil)
            .navigationTitle("settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") { dismiss() }
                }
            }
        }
        .onChange(of: media) { _, on in
            Task { await suggestions.prefs(for: boards.personId, media: on) }
        }
        .onChange(of: events) { _, on in
            Task { await suggestions.prefs(for: boards.personId, events: on) }
        }
    }
}
