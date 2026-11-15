import type { AuthConfig } from "convex/server";

export default {
  providers: [
    { domain: "https://appleid.apple.com", applicationID: "com.panthb.appdemo" },
    { domain: "https://accounts.google.com", applicationID: "REPLACE_WITH_GOOGLE_IOS_CLIENT_ID.apps.googleusercontent.com" },
  ],
} satisfies AuthConfig;
