import os
import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let state = ShareState()

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareNote(state: state))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        Task { @MainActor in
            state.saved = await save()
            try? await Task.sleep(for: .milliseconds(900))
            extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func save() async -> Bool {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        var url: String?
        var text: String?
        for provider in providers {
            if url == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                url = item.absoluteString
            } else if text == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                      let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                text = item
            }
        }
        guard url != nil || text != nil else {
            Logger.share.error("the share stub only keeps links and text so far")
            return false
        }
        guard let inbox = Inbox.shared else {
            Logger.share.fault("app group is missing, so the share extension can't reach the inbox")
            return false
        }
        do {
            let item = try inbox.write(InboxItem(kind: url == nil ? .text : .url, text: text, url: url))
            Logger.share.info("dropped \(item.id.uuidString, privacy: .public) into the inbox")
            return true
        } catch {
            Logger.share.error("writing to the inbox failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }
}

@MainActor
private final class ShareState: ObservableObject {
    @Published var saved: Bool?
}

private struct ShareNote: View {
    @ObservedObject var state: ShareState

    var body: some View {
        Text(message)
            .font(.system(.title3, design: .rounded))
            .multilineTextAlignment(.center)
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.98, green: 0.96, blue: 0.91))
    }

    private var message: String {
        switch state.saved {
        case .none: "dropping it…"
        case .some(true): "dropped it, i'll find it a spot."
        case .some(false): "i can't keep this kind of thing yet, but it's coming soon."
        }
    }
}
