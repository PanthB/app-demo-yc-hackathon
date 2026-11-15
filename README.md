# Resona

My solo project for The Consumer Mobile Hackathon (YC, San Francisco, November 15, 2026).

## Stack

- **iOS app:** native Swift and SwiftUI, using the [ConvexMobile](https://github.com/convex/convex-swift) client.
- **Backend:** [Convex](https://convex.dev) for the database and server functions in `convex/`.
- **Builds and devices:** [Revyl](https://revyl.ai) build runners and cloud iPhones, driven through [Capy](https://capy.ai).

## Backend

```sh
npm install
npx convex dev
```

`npx convex dev` signs you in, syncs the functions in `convex/` to your dev deployment, and keeps watching for changes. With `CONVEX_DEPLOY_KEY` set, `npx convex dev --once` pushes them once without a login.
