import type { AuthConfig } from "convex/server";

export default {
  providers: [{ domain: "https://appleid.apple.com", applicationID: "com.panthb.appdemo" }],
} satisfies AuthConfig;
