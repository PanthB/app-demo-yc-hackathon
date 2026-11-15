# Auth

Owner: APPD-17.

Sign in with Apple, the one account provider. Sign-in is optional: a guest is this phone's anonymous `DeviceIdentity.personId`, registered through `people:upsert` like every person, and the demo needs no account either. There's no other anonymous auth layer.

- `AppleSignIn.signIn()` runs the system prompt through `ASAuthorizationController`, so the sheet draws its own lowercase button. `AppleSignIn.isEnabled` is the one switch: set it to false for a build signed by a Personal Team, and start fresh goes in as a guest without the sheet. Apple gives the name only on an account's first sign-in, so later sign-ins keep the saved one.
- `AccountStore.shared` (main actor, observable) holds the signed-in `AccountSession` (the Apple identity token, its expiry, name and email), kept in the Keychain.
- `AccountAuthProvider` is the `AuthProvider` behind the app's `convex` client, which is a `ConvexClientWithAuth<AccountSession>` (ios/App/Convex.swift). It hands Convex the saved token. Apple's token lasts ten minutes and can't be refreshed without a server, which is fine: only the link needs it, and boards go by the person id.
- `PeopleLink.link(_:)` runs right after sign-in: `convex.login()`, then `people:link { personId, personalBoardId, name }` (see handoffs/APPD-1/convex-contract.md in the crew drive). On an account's first sign-in it ties the account to this phone's person, so a guest keeps their boards. When the account already belongs to another person, the phone adopts that person and the caller restarts `BoardsStore`, so their boards come back. If the link fails, the sheet signs out again and says so in plain words, and the person carries on as a guest.
- Signing needs the `com.apple.developer.applesignin` entitlement (`Default`) and a paid team; the backend trusts the issuer `https://appleid.apple.com` with the bundle id as audience.

Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build.
