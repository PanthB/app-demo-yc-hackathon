import os
import PhotosUI
import SwiftUI
import UIKit

struct AddMenu: View {
    @Environment(BoardSync.self) private var sync
    @Environment(\.modelContext) private var context
    @State private var isTakingPhoto = false
    @State private var isPickingPhotos = false
    @State private var picked: [PhotosPickerItem] = []
    @State private var writing: Writing?
    @State private var words = ""

    private enum Writing {
        case link, note
    }

    var body: some View {
        Menu {
            Button {
                isTakingPhoto = true
            } label: {
                Label("take a photo", systemImage: "camera")
            }
            Button {
                isPickingPhotos = true
            } label: {
                Label("choose a photo", systemImage: "photo")
            }
            Button {
                words = UIPasteboard.general.hasURLs ? (UIPasteboard.general.url?.absoluteString ?? "") : ""
                writing = .link
            } label: {
                Label("paste link", systemImage: "link")
            }
            Button {
                words = ""
                writing = .note
            } label: {
                Label("note", systemImage: "note.text")
            }
        } label: {
            Label("add something to the board", systemImage: "plus")
                .labelStyle(.iconOnly)
        }
        .accessibilityIdentifier("addMenu")
        .fullScreenCover(isPresented: $isTakingPhoto) {
            DropCamera()
                .environment(sync)
                .environment(sync.boards)
        }
        .photosPicker(isPresented: $isPickingPhotos, selection: $picked, maxSelectionCount: 4, matching: .images)
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            picked = []
            Task { await keep(items) }
        }
        .alert("paste a link", isPresented: isWriting(.link)) {
            TextField("https://", text: $words)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Button("add it") { addWords(asLink: true) }
            Button("never mind", role: .cancel) {}
        } message: {
            Text("i'll put it on the board and work out what it is.")
        }
        .alert("write a note", isPresented: isWriting(.note)) {
            TextField("remind me in 1 hr to call mom", text: $words)
            Button("add it") { addWords(asLink: false) }
            Button("never mind", role: .cancel) {}
        } message: {
            Text("say when, and i'll put it where it belongs.")
        }
    }

    private func isWriting(_ kind: Writing) -> Binding<Bool> {
        Binding(
            get: { writing == kind },
            set: { isShown in
                if !isShown, writing == kind { writing = nil }
            }
        )
    }

    private func addWords(asLink: Bool) {
        let text = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let link = asLink ? Self.link(from: text) : nil
        drop(link.map { InboxItem(kind: .url, url: $0) } ?? InboxItem(kind: .text, text: text))
        sync.wake(in: context)
    }

    static func link(from text: String) -> String? {
        guard !text.contains(where: \.isWhitespace) else { return nil }
        let candidate = text.contains("://") ? text : "https://\(text)"
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host(), host.contains(".")
        else { return nil }
        return candidate
    }

    private func keep(_ items: [PhotosPickerItem]) async {
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    Logger.sync.error("a picked photo came back empty")
                    continue
                }
                let fileExtension = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                drop(InboxItem(kind: .image), payloads: [.data(data, name: "photo.\(fileExtension)")])
            } catch {
                Logger.sync.error("a picked photo couldn't be loaded: \(String(describing: error), privacy: .public)")
            }
        }
        sync.wake(in: context)
    }

    private func drop(_ item: InboxItem, payloads: [InboxPayload] = []) {
        guard let inbox = Inbox.shared else {
            Logger.sync.fault("app group is missing, so nothing can be added from the app")
            return
        }
        do {
            try inbox.write(item, payloads: payloads)
        } catch {
            Logger.sync.error("couldn't add a \(item.kind.rawValue, privacy: .public) from the app: \(String(describing: error), privacy: .public)")
        }
    }
}
