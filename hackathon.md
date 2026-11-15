# Hackathon log

- **Project:** app-demo-yc-hackathon
- **Event:** The Consumer Mobile Hackathon
- **What it does:** Not documented yet
- **Live app:** not deployed
- **Repo:** private
- **Frontend:** not deployed
- **Convex deployment:** https://adorable-coyote-696.convex.cloud
- **Components:** none
- **Convex features:** schema, tables, indexes, queries, mutations
- **Auth:** none
- **AI models:** none
- **Started:** 2026-11-15T18:36:06Z
- **Last updated:** 2026-11-15T18:36:06Z

## Log

### 2026-11-15 - 892b8fd
Set up the Convex backend: a `moments` table (text, author, createdAt) with an
index on createdAt, a query that lists the newest 100 moments first, and a
mutation that adds one, pushed to the dev deployment. Convex features: schema,
indexes, query, mutation (`convex/schema.ts`, `convex/moments.ts`).
