import { defineApp } from "convex/server";
import { v } from "convex/values";

const app = defineApp({
  env: {
    OPENROUTER_API_KEY: v.optional(v.string()),
    SUPERMEMORY_API_KEY: v.optional(v.string()),
    READER_MODEL: v.optional(v.string()),
  },
});

export default app;
