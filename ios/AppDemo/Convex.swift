import ConvexMobile
import Foundation
import os

let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AppDemo", category: "app")

let convex: ConvexClient = {
    guard let url = Bundle.main.object(forInfoDictionaryKey: "CONVEX_URL") as? String, !url.isEmpty else {
        logger.fault("CONVEX_URL is missing from Info.plist; set it in Config/AppDemo.xcconfig")
        fatalError("CONVEX_URL is missing from Info.plist")
    }
    logger.info("Connecting to Convex at \(url, privacy: .public)")
    return ConvexClient(deploymentUrl: url)
}()
