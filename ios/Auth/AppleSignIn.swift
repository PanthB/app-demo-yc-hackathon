import AuthenticationServices
import os
import UIKit

enum AppleSignIn {
    /// The one switch for Sign in with Apple. It needs a paid team with the capability on the app ID, so a build
    /// signed by a Personal Team turns it off and the sheet shows Google and "not now" alone.
    static let isEnabled = true

    static func prepare(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    /// Runs the system's Sign in with Apple prompt. Nil means the person cancelled it.
    @MainActor
    static func signIn() async throws -> AccountSession? {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        prepare(request)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleAuthorizationDelegate()
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        let result = await withCheckedContinuation { continuation in
            delegate.done = { continuation.resume(returning: $0) }
            controller.performRequests()
        }
        withExtendedLifetime((controller, delegate)) {}
        return try session(from: result)
    }

    static func session(from result: Result<ASAuthorization, Error>) throws -> AccountSession? {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return nil }
            Logger.auth.error("sign in with apple failed: \(String(describing: error), privacy: .public)")
            throw error
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken,
                  let token = String(data: data, encoding: .utf8)
            else {
                Logger.auth.error("sign in with apple returned no identity token")
                throw AccountError.missingToken
            }
            let name = credential.fullName.flatMap {
                PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
            }
            return AccountSession(method: .apple, idToken: token, name: name?.isEmpty == false ? name : nil, email: credential.email)
        }
    }
}

@MainActor
private final class AppleAuthorizationDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var done: ((Result<ASAuthorization, Error>) -> Void)?

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        done?(.success(authorization))
        done = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        done?(.failure(error))
        done = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return scene?.keyWindow ?? scene?.windows.first ?? ASPresentationAnchor()
    }
}
