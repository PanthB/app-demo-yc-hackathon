import { defineApp } from "convex/server";
import { v } from "convex/values";

const app = defineApp({
  env: {
    SUPERMEMORY_API_KEY: v.optional(v.string()),
    SCRAPECREATORS_API_KEY: v.optional(v.string()),
    OPENAI_API_KEY: v.optional(v.string()),
    OPENAI_READER_MODEL: v.optional(v.string()),
    OPENAI_DECIDER_MODEL: v.optional(v.string()),
    OPENAI_SUGGESTIONS_MODEL: v.optional(v.string()),
    OPENAI_BUDGET_USD: v.optional(v.string()),
  },
});

export default app;
