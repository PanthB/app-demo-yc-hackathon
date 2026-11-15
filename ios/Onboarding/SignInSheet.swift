import AuthenticationServices
import os
import SwiftUI

enum SignInOutcome: Equatable {
    case skipped
    case signedIn(AccountSession)
}

/// The bottom sheet over the welcome when someone starts fresh: Apple, Google, or not now. Each provider shows
/// only when it's switched on: `AppleSignIn.isEnabled`, and `GoogleSignIn.isConfigured` once it has a client ID.
struct SignInSheet: View {
    let onDone: (SignInOutcome) -> Void

    static var isAvailable: Bool {
        AppleSignIn.isEnabled || GoogleSignIn.isConfigured
    }

    /// The sheet's fixed height, so it never resizes after it appears: 64pt for each provider it shows.
    static var height: CGFloat {
        244 + 64 * CGFloat([AppleSignIn.isEnabled, GoogleSignIn.isConfigured].filter { $0 }.count)
    }

    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @State private var working = false
    @State private var problem: String?
    @State private var welcomed: String?

    var body: some View {
        VStack(spacing: 0) {
            Text(welcomed.map { "you're in, \($0)." } ?? "sign in")
                .font(.system(size: 24, weight: .bold))
                .contentTransition(.interpolate)
            ZStack {
                Text(problem ?? "so your boards and your friends come with you to any phone.")
                    .id(problem)
                    .transition(.blurReplace)
            }
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(height: 44)
            .padding(.top, 6)
            .padding(.bottom, 24)

            VStack(spacing: 12) {
                if AppleSignIn.isEnabled {
                    ProviderButton(title: "continue with apple", prominent: true) {
                        Task { await signInWithApple() }
                    } icon: {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 19, weight: .medium))
                    }
                    .accessibilityIdentifier("signInApple")
                }
                if GoogleSignIn.isConfigured {
                    ProviderButton(title: "continue with google", prominent: !AppleSignIn.isEnabled) {
                        Task { await signInWithGoogle() }
                    } icon: {
                        Image("google-g")
                            .resizable()
                            .frame(width: 18, height: 18)
                    }
                    .accessibilityIdentifier("signInGoogle")
                }
            }
            .disabled(working)

            Button("not now") {
                onDone(.skipped)
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
            .padding(.top, 16)
            .accessibilityIdentifier("signInNotNow")
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.smooth(duration: 0.25), value: problem)
        .tint(.white)
    }

    private func signInWithApple() async {
        working = true
        defer { working = false }
        do {
            guard let session = try await AppleSignIn.signIn() else { return }
            finish(session)
        } catch {
            problem = "apple sign-in didn't go through on this phone, so you can skip it for now."
        }
    }

    private func signInWithGoogle() async {
        working = true
        defer { working = false }
        do {
            let attempt = try GoogleSignIn.begin()
            let callback = try await webAuthenticationSession.authenticate(
                using: attempt.url,
                callbackURLScheme: GoogleSignIn.callbackScheme,
                preferredBrowserSession: .shared
            )
            finish(try await GoogleSignIn.finish(attempt, callback: callback))
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return
        } catch {
            Logger.auth.error("google sign-in failed: \(String(describing: error), privacy: .public)")
            problem = "google sign-in didn't go through, so you can try again or skip it for now."
        }
    }

    private func finish(_ session: AccountSession) {
        AccountStore.shared.signedIn(session)
        problem = nil
        withAnimation(.smooth) { welcomed = session.firstName ?? "friend" }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            onDone(.signedIn(session))
        }
    }
}

/// Both providers share one shape: the same height, type and spacing, a white pill for the first and a grey one
/// for the second, so the second still reads as a button on the sheet's own glass.
private struct ProviderButton<Icon: View>: View {
    let title: String
    let prominent: Bool
    let action: () -> Void
    @ViewBuilder var icon: Icon

    var body: some View {
        if prominent {
            Button(action: action) { label.foregroundStyle(.black) }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        } else {
            Button(action: action) { label.foregroundStyle(.white) }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(Color(white: 0.3))
        }
    }

    private var label: some View {
        HStack(spacing: 10) {
            icon
            Text(title)
        }
        .font(.system(size: 17, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: 40)
    }
}
