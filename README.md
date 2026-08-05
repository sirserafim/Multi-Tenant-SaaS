# Xperio

A full-stack, multi-tenant **TypeScript** web application, built as a portfolio
project with a deliberate bias: **correctness, type-safety and security posture
matter more than feature volume.**

> **Status:** 🚧 In active development (2026). Built in phases — see the roadmap below.

## Tech stack

| Layer     | Technology |
|-----------|------------|
| Web       | Next.js 15 (App Router), React 19, TypeScript, Tailwind CSS |
| API       | Node.js, Express, TypeScript |
| Database  | PostgreSQL (Supabase) with Row-Level Security enabled on every table |
| Contracts | Zod schemas, shared between web and API as the single source of truth |

## Engineering focus

The interesting parts of this project are not the screens — they're the guarantees:

- **Row-Level Security everywhere.** Every table has RLS enabled with explicit
  policies. The public reads only published data; the service role is server-only.
- **Append-only ledger.** Earning-events are recorded as immutable rows. Amounts are
  stored as integers in minor units — never floats.
- **Concurrency-safe writes.** Mutation paths are designed to be correct even under
  two simultaneous requests (row locking, not naive counts).
- **Idempotent telemetry.** A replayed request can never create a duplicate credit,
  enforced at the database layer.
- **Shared Zod contracts.** Types are defined once and derived with `z.infer`, so the
  web and API can never drift apart.
- **Strict TypeScript.** `strict: true`, `noImplicitAny: true`, no `any`, no `@ts-ignore`.

## Monorepo layout

```
/apps/xperio-web        # Next.js frontend
/apps/xperio-api        # Express telemetry API
/packages/contracts     # Shared Zod schemas + inferred types (source-only, no build step)
```

## Roadmap

- [ ] **Phase 1** — Architecture, workspace config, shared Zod contracts
- [ ] **Phase 2** — PostgreSQL schema, RLS policies, triggers, seed data
- [ ] **Phase 3** — Express telemetry API (validation, transactions, anti-abuse)
- [ ] **Phase 4** — Next.js frontend (server components, accessible modal, telemetry)

## Author

Serafeim Saratsis — building this to learn modern full-stack engineering properly,
one phase at a time.
