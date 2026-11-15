import SwiftUI
import UIKit

enum CameraDebug {
    static var mayDrop: Bool {
        #if DEBUG
        !usesStill || UserDefaults.standard.bool(forKey: "BoardDebugSeed")
        #else
        true
        #endif
    }
}

#if DEBUG
extension CameraDebug {
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

    static var autoShotGaps: [Double] {
        guard let plan = UserDefaults.standard.string(forKey: "CameraDebugShotGaps") else { return [2.2, 2.2] }
        return plan.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }

    static let stills = ["seed-dolores-sunny", "seed-pinksky", "seed-landsend", "seed-matcha"]

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
