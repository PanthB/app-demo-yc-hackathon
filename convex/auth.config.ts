import type { AuthConfig } from "convex/server";

export default {
  providers: [
    { domain: "https://appleid.apple.com", applicationID: "com.panthb.appdemo" },
    { domain: "https://appleid.apple.com", applicationID: "app.resona.ios" },
  ],
} satisfies AuthConfig;
