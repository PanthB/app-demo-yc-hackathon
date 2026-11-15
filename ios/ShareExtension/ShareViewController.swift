import os
import SwiftUI
import UIKit

final class ShareViewController: UIViewController {
    private let state = ShareState()
    private let boardId = AppGroup.defaults.string(forKey: "currentBoardId")
    private let sharedBoardName = AppGroup.defaults.bool(forKey: "currentBoardShared")
        ? AppGroup.defaults.string(forKey: "currentBoardName")
        : nil
    private var isOnScreen = false
    private var isClosingSoon = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        let host = UIHostingController(rootView: ShareNote(state: state, boardName: sharedBoardName, close: { [weak self] in self?.close() }))
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        Task { @MainActor in
            let saved = await save()
            state.outcome = saved ? .dropped : .failed
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            closeSoon()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Logger.share.info("the share card is on screen")
        isOnScreen = true
        closeSoon()
    }

    private func closeSoon() {
        guard isOnScreen, state.outcome != nil, !isClosingSoon else { return }
        isClosingSoon = true
        #if DEBUG
        if AppGroup.defaults.bool(forKey: "holdShareNote") {
            Logger.share.info("the share note stays until it's tapped")
            return
        }
        #endif
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            close()
        }
    }

    private func close() {
        guard !state.isLeaving else { return }
        state.isLeaving = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func save() async -> Bool {
        guard let inbox = Inbox.shared else {
            Logger.share.fault("app group is missing, so the share extension can't reach the inbox")
            return false
        }
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let saved = await ShareCollector.save(items, to: inbox)
        for id in saved {
            if let boardId { AppGroup.defaults.set(boardId, forKey: "inboxBoard.\(id.uuidString)") }
        }
        if saved.isEmpty {
            Logger.share.error("nothing in this share could be kept")
        }
        return !saved.isEmpty
    }
}

@MainActor
final class ShareState: ObservableObject {
    enum Outcome {
        case dropped, failed
    }

    @Published var outcome: Outcome?
    @Published var isLeaving = false
}
