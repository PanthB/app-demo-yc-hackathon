import ConvexMobile
import Foundation
import os

/// The person people:link answers with: this phone's person on an account's first sign-in, or the person the
/// Apple account already belongs to.
struct LinkedPerson: Decodable, Equatable {
    let personId: String
    let name: String
    let personalBoardId: String
}

enum PeopleLink {
    /// Hands Convex the Apple token, then ties the account to this phone's person, so a guest keeps their boards.
    /// When the account already belongs to another person (a reinstall, a second phone), the phone becomes that
    /// person and gets their boards back; the caller restarts the boards store to pick them up.
    @MainActor
    static func link(_ session: AccountSession) async throws -> LinkedPerson {
        if case .failure(let error) = await convex.login() {
            Logger.auth.error("convex didn't take the apple token: \(String(describing: error), privacy: .public)")
            throw AccountError.notLinked("sign in with apple first.")
        }
        do {
            let person: LinkedPerson = try await convex.mutation("people:link", with: [
                "personId": DeviceIdentity.personId,
                "personalBoardId": BoardKeys.personalBoard,
                "name": session.firstName,
            ])
            if person.personId != DeviceIdentity.personId {
                Logger.auth.info("this apple account already has a person, so the phone becomes them")
                DeviceIdentity.adopt(personId: person.personId, boardId: person.personalBoardId)
            }
            Logger.auth.info("linked the apple account to this phone's person")
            return person
        } catch let ClientError.ConvexError(data) {
            let reason = (try? JSONDecoder().decode(String.self, from: Data(data.utf8))) ?? data
            Logger.auth.error("people:link refused: \(reason, privacy: .public)")
            throw AccountError.notLinked(reason)
        }
    }
}
