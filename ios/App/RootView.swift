import os
import SwiftUI

struct RootView: View {
    @AppStorage(Look.storageKey) private var storedLook: String?

    var body: some View {
        Group {
            switch Look.resolve(stored: storedLook) {
            case .paper:
                MomentsView()
            case .glass:
                GlassBoardRoot()
            }
        }
        .onOpenURL { url in
            guard let look = Look(url: url) else {
                Logger.app.error("ignored a link the app doesn't handle: \(url.absoluteString, privacy: .public)")
                return
            }
            Logger.app.info("switching to the \(look.rawValue, privacy: .public) look")
            storedLook = look.rawValue
        }
    }
}
