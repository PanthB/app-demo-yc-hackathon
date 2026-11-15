# Auth

Owner: APPD-17.

Sign in with Apple and Google, kept in the Keychain and handed to Convex through ConvexMobile's `ConvexClientWithAuth`.

- `AccountStore.shared` (main actor, observable) holds the signed-in `AccountSession` (method, ID token, expiry, name, email). The onboarding sign-in sheet fills it.
- `AccountAuthProvider` is the `AuthProvider` for `ConvexClientWithAuth<AccountSession>(deploymentUrl:authProvider:)`. Its `login` and `loginFromCache` return the stored session, refreshing a Google token when it has run out. An Apple identity token lasts ten minutes and can't be refreshed without a server, so link the identity right after sign-in.
- Wiring for the sync owner: build the client with `AccountAuthProvider()`, call `loginFromCache()` on launch, and call `login()` when `AccountStore.shared.session` goes from nil to a session, then the backend's link mutation.
- `GoogleSignIn.clientID` is the one constant to fill in: the iOS OAuth client ID for `com.panthb.appdemo`. While it's empty the sheet leaves Google out, so filling it in is the whole change that brings Google back. Google runs in the system web sign-in sheet (ASWebAuthenticationSession with PKCE), so there's no SDK and no URL scheme to register.
- Sign in with Apple needs the `com.apple.developer.applesignin` entitlement (`Default`) in Config/App.entitlements and a paid team for signing. `AppleSignIn.isEnabled` is the one switch: set it to false for a Personal Team build and the sheet shows Google and "not now" alone. The button is drawn in the sheet's own style and runs `ASAuthorizationController` directly, so its label stays lowercase.

Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build.
