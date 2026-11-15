import ConvexMobile
import Foundation
import os

let convex: ConvexClientWithAuth<AccountSession> = {
    guard let url = Bundle.main.object(forInfoDictionaryKey: "CONVEX_URL") as? String, !url.isEmpty else {
        Logger.app.fault("CONVEX_URL is missing from Info.plist; set it in Config/AppDemo.xcconfig")
        fatalError("CONVEX_URL is missing from Info.plist")
    }
    Logger.app.info("connecting to convex at \(url, privacy: .public)")
    return ConvexClientWithAuth(deploymentUrl: url, authProvider: AccountAuthProvider())
}()
