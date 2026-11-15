import SwiftUI
import UIKit

#if DEBUG
enum CameraDebug {
    static var usesStill: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        UserDefaults.standard.bool(forKey: "CameraDebugStill")
        #endif
    }

    static var opensOnLaunch: Bool {
        UserDefaults.standard.bool(forKey: "CameraDebugOpen")
    }

    static var autoShootDelay: Double? {
        let seconds = UserDefaults.standard.double(forKey: "CameraDebugAutoShoot")
        return seconds > 0 ? seconds : nil
    }

    static var forcedAccess: CameraAccess? {
        switch UserDefaults.standard.string(forKey: "CameraDebugAccess") {
        case "notAsked": .notAsked
        case "denied": .denied
        case "unavailable": .unavailable
        default: nil
        }
    }

    static let autoShots = 3

    static let stills = ["seed-dolores-sunny", "seed-pinksky", "seed-lights", "seed-landsend", "seed-matcha"]

    static func still(_ index: Int) -> UIImage? {
        UIImage(named: stills[index % stills.count])
    }
}

private struct CameraDebugLauncher: ViewModifier {
    @State private var isOpen = CameraDebug.opensOnLaunch

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $isOpen) {
            DropCamera()
        }
    }
}
#endif

extension View {
    func cameraDebugLauncher() -> some View {
        #if DEBUG
        modifier(CameraDebugLauncher())
        #else
        self
        #endif
    }
}
