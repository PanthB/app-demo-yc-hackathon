import os
import SwiftUI

struct OnboardingResult: Equatable, Sendable {
    enum Start: String, Sendable {
        case demo, fresh
    }

    let start: Start
    let name: String?
}

enum Onboarding {
    static let doneKey = "onboardingDone"
    static let demoInviteCode = "SFCREW"
    static let demoBoardName = "sf crew"

    /// True on first launch, and on every DEBUG launch with `-OnboardingReset YES`.
    static var isNeeded: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "OnboardingReset") { return true }
        #endif
        return !UserDefaults.standard.bool(forKey: doneKey)
    }

    static func markDone() {
        UserDefaults.standard.set(true, forKey: doneKey)
    }

    static let appName: String = {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        return (name ?? "moments").lowercased()
    }()
}

extension Logger {
    static let onboarding = Logger(subsystem: subsystem, category: "onboarding")
}

extension Color {
    static let onboardingTint = Color(red: 1.0, green: 0.42, blue: 0.29)
}
