import { defineApp } from "convex/server";
import { v } from "convex/values";

const app = defineApp({
  env: {
    OPENROUTER_API_KEY: v.optional(v.string()),
    SUPERMEMORY_API_KEY: v.optional(v.string()),
    READER_MODEL: v.optional(v.string()),
    DECIDER_MODEL: v.optional(v.string()),
    SCRAPECREATORS_API_KEY: v.optional(v.string()),
    OPENAI_API_KEY: v.optional(v.string()),
    OPENAI_READER_MODEL: v.optional(v.string()),
    OPENAI_DECIDER_MODEL: v.optional(v.string()),
    OPENAI_BUDGET_USD: v.optional(v.string()),
    MODEL_PROFILE: v.optional(v.string()),
    READER_PROFILE: v.optional(v.string()),
  },
});

export default app;
