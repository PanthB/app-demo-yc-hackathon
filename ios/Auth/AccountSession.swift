import Foundation
import os
import Security

extension Logger {
    static let auth = Logger(subsystem: subsystem, category: "auth")
}

enum SignInMethod: String, Codable, Sendable {
    case apple
}

enum AccountError: LocalizedError {
    case signedOut
    case expired
    case missingToken
    case notLinked(String)

    var errorDescription: String? {
        switch self {
        case .signedOut: "nobody is signed in on this phone."
        case .expired: "the sign-in ran out, so it needs doing again."
        case .missingToken: "the sign-in came back without a token."
        case .notLinked(let reason): "the account couldn't be tied to this phone: \(reason)"
        }
    }
}

struct AccountSession: Codable, Equatable, Sendable {
    let method: SignInMethod
    var idToken: String
    var expiresAt: Date
    var name: String?
    var email: String?

    var firstName: String? {
        name?.split(separator: " ").first.map { $0.lowercased() }
    }

    var isExpired: Bool {
        expiresAt.timeIntervalSinceNow < 60
    }

    init(method: SignInMethod, idToken: String, name: String?, email: String?) {
        let claims = JWTClaims(idToken)
        self.method = method
        self.idToken = idToken
        self.expiresAt = claims.expiresAt ?? .now.addingTimeInterval(600)
        self.name = name ?? claims.name
        self.email = email ?? claims.email
    }
}

struct JWTClaims {
    let expiresAt: Date?
    let name: String?
    let email: String?

    init(_ token: String) {
        let parts = token.split(separator: ".")
        var payload = parts.count > 1 ? String(parts[1]) : ""
        payload = payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        let object = Data(base64Encoded: payload)
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        expiresAt = (object["exp"] as? Double).map { Date(timeIntervalSince1970: $0) }
        name = (object["given_name"] as? String) ?? (object["name"] as? String)
        email = object["email"] as? String
    }
}

enum AccountKeychain {
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.panthb.appdemo.account",
        kSecAttrAccount as String: "session",
    ]

    static func load() -> AccountSession? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                Logger.auth.error("reading the saved sign-in failed with status \(status)")
            }
            return nil
        }
        return try? JSONDecoder().decode(AccountSession.self, from: data)
    }

    static func save(_ session: AccountSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(item as CFDictionary, nil)
        if status != errSecSuccess {
            Logger.auth.error("saving the sign-in failed with status \(status)")
        }
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
@Observable
final class AccountStore {
    static let shared = AccountStore()

    private(set) var session: AccountSession? = AccountKeychain.load()

    func signedIn(_ session: AccountSession) {
        AccountKeychain.save(session)
        self.session = session
        Logger.auth.info("signed in with \(session.method.rawValue, privacy: .public)")
    }

    func signOut() {
        AccountKeychain.delete()
        session = nil
    }
}
