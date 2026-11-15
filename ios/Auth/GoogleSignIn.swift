import CryptoKit
import Foundation
import os

enum GoogleSignIn {
    /// The iOS OAuth client ID from Google Cloud for com.panthb.appdemo, like "1234-abcd.apps.googleusercontent.com".
    /// This is the switch for Google: while it's empty, the sign-in sheet leaves Google out.
    static let clientID = ""

    static var isConfigured: Bool {
        !clientID.isEmpty
    }

    static var callbackScheme: String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    private static var redirectURI: String {
        callbackScheme + ":/oauth2redirect"
    }

    struct Attempt {
        let url: URL
        fileprivate let verifier: String
        fileprivate let state: String
    }

    static func begin() throws -> Attempt {
        guard isConfigured else { throw AccountError.notConfigured }
        let verifier = randomURLSafe(bytes: 32)
        let state = randomURLSafe(bytes: 16)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
        var parts = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        parts.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        return Attempt(url: parts.url!, verifier: verifier, state: state)
    }

    static func finish(_ attempt: Attempt, callback: URL) async throws -> AccountSession {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == attempt.state,
              let code = items.first(where: { $0.name == "code" })?.value
        else {
            let reason = items.first(where: { $0.name == "error" })?.value ?? "no code"
            throw AccountError.badResponse(reason)
        }
        let tokens = try await token([
            "grant_type": "authorization_code",
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "code_verifier": attempt.verifier,
        ])
        guard let idToken = tokens.id_token else { throw AccountError.missingToken }
        return AccountSession(method: .google, idToken: idToken, name: nil, email: nil, refreshToken: tokens.refresh_token)
    }

    static func refresh(_ session: AccountSession) async throws -> AccountSession {
        guard let refreshToken = session.refreshToken else { throw AccountError.expired }
        let tokens = try await token([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
        ])
        guard let idToken = tokens.id_token else { throw AccountError.missingToken }
        var renewed = AccountSession(method: .google, idToken: idToken, name: session.name, email: session.email, refreshToken: refreshToken)
        renewed.refreshToken = tokens.refresh_token ?? refreshToken
        return renewed
    }

    private struct Tokens: Decodable {
        let id_token: String?
        let refresh_token: String?
    }

    private static func token(_ form: [String: String]) async throws -> Tokens {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var body = URLComponents()
        body.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            Logger.auth.error("google token exchange failed with status \(status)")
            throw AccountError.badResponse("status \(status)")
        }
        return try JSONDecoder().decode(Tokens.self, from: data)
    }

    private static func randomURLSafe(bytes count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes).base64URLEncoded
    }
}

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
