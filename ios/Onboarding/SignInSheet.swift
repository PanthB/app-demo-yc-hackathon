import os
import SwiftUI

enum SignInOutcome: Equatable {
    case guest
    case demo
    case signedIn(AccountSession)
}

/// The sheet over the welcome when someone starts fresh, with the three ways in: Sign in with Apple, which ties
/// the account to this phone's person so their boards can follow them; a guest, who is just this phone's person
/// with no account; and the sf crew demo.
struct SignInSheet: View {
    let onDone: (SignInOutcome) -> Void

    static var isAvailable: Bool { AppleSignIn.isEnabled }

    /// Fixed, so the sheet never resizes after it appears.
    static let height: CGFloat = 372

    @State private var working = false
    @State private var problem: String?
    @State private var welcomed: String?

    var body: some View {
        VStack(spacing: 0) {
            Text(welcomed.map { "you're in, \($0)." } ?? "start fresh")
                .font(.system(size: 24, weight: .bold))
                .contentTransition(.interpolate)
            ZStack {
                Text(problem ?? "with apple, your boards follow you to any phone. as a guest, they stay on this one.")
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
                ChoiceButton(title: "continue with apple", prominent: true) {
                    Task { await signInWithApple() }
                } icon: {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 19, weight: .medium))
                }
                .accessibilityIdentifier("signInApple")
                ChoiceButton(title: "continue as a guest", prominent: false) {
                    onDone(.guest)
                } icon: {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16, weight: .medium))
                }
                .accessibilityIdentifier("signInGuest")
            }
            .disabled(working)

            Button("or open the \(Onboarding.demoBoardName) demo") {
                onDone(.demo)
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
            .padding(.top, 16)
            .disabled(working)
            .accessibilityIdentifier("signInDemo")
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.smooth(duration: 0.25), value: problem)
        .tint(.white)
    }

    /// Signs in with Apple, then links the account through people:link. The session is kept only once the link
    /// went through, so a failed link leaves the person a guest who can try again.
    private func signInWithApple() async {
        working = true
        defer { working = false }
        let session: AccountSession
        do {
            guard let signedIn = try await AppleSignIn.signIn() else { return }
            session = signedIn
        } catch {
            problem = "apple sign-in didn't go through, so try again or carry on as a guest."
            return
        }
        AccountStore.shared.signedIn(session)
        do {
            _ = try await PeopleLink.link(session)
        } catch {
            await convex.logout()
            if case AccountError.notLinked(let reason) = error, reason.contains("another account") {
                problem = "this phone is already tied to another apple account, so carry on as a guest."
            } else {
                problem = "apple signed you in, but your boards didn't hear about it, so try again or carry on as a guest."
            }
            return
        }
        problem = nil
        withAnimation(.smooth) { welcomed = session.firstName ?? "friend" }
        try? await Task.sleep(for: .milliseconds(900))
        onDone(.signedIn(session))
    }
}

/// The sheet's two ways in share one shape: the same height, type and spacing, a white pill for Apple and a grey
/// one for the guest, so the guest still reads as a real choice on the sheet's own glass.
private struct ChoiceButton<Icon: View>: View {
    let title: String
    let prominent: Bool
    let action: () -> Void
    @ViewBuilder var icon: Icon

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon
                Text(title)
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(prominent ? Color.black : Color.white)
            .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .tint(prominent ? Color.white : Color(white: 0.3))
    }
}
