import ConvexMobile
import Foundation

/// The AuthProvider behind ConvexClientWithAuth. The sign-in sheet does the interactive part and keeps the
/// session in the Keychain; login and loginFromCache hand Convex that session's ID token, refreshing a
/// Google token when it has run out. Apple identity tokens last ten minutes and can't be refreshed
/// without a server, so an expired Apple session reads as signed out until the person signs in again.
final class AccountAuthProvider: AuthProvider {
    typealias T = AccountSession

    func login(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> AccountSession {
        try await loginFromCache(onIdToken: onIdToken)
    }

    func loginFromCache(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> AccountSession {
        guard let session = AccountKeychain.load() else { throw AccountError.signedOut }
        guard session.isExpired else { return session }
        guard session.method == .google else { throw AccountError.expired }
        let renewed = try await GoogleSignIn.refresh(session)
        AccountKeychain.save(renewed)
        onIdToken(renewed.idToken)
        return renewed
    }

    func logout() async throws {
        await AccountStore.shared.signOut()
    }

    func extractIdToken(from authResult: AccountSession) -> String {
        authResult.idToken
    }
}
