import ConvexMobile
import Foundation

/// The AuthProvider behind ConvexClientWithAuth. The sign-in sheet does the interactive part and keeps the
/// session in the Keychain; login and loginFromCache hand Convex that session's Apple identity token. The token
/// lasts ten minutes and can't be refreshed without a server, so the app links the account right after sign-in,
/// and an expired session reads as signed out to Convex. Boards don't need it: they go by the phone's person.
final class AccountAuthProvider: AuthProvider {
    typealias T = AccountSession

    func login(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> AccountSession {
        try await loginFromCache(onIdToken: onIdToken)
    }

    func loginFromCache(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> AccountSession {
        guard let session = AccountKeychain.load() else { throw AccountError.signedOut }
        guard !session.isExpired else { throw AccountError.expired }
        return session
    }

    func logout() async throws {
        await AccountStore.shared.signOut()
    }

    func extractIdToken(from authResult: AccountSession) -> String {
        authResult.idToken
    }
}
