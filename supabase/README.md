# Supabase backend for OkiMission

This directory contains the database schema, RLS policies, stored procedures,
pg_cron schedules, and Deno Edge Functions used by the OkiMission iOS app.

## Layout

```
supabase/
  config.toml                    Local dev configuration (Supabase CLI)
  migrations/                    SQL migrations, run in lexicographic order
    20260601000000_initial_schema.sql
    20260601000001_initial_indexes.sql
    20260601000002_initial_rls.sql
    20260601000003_initial_functions.sql
    20260601000004_initial_triggers.sql
    20260601000005_initial_cron.sql
  functions/
    _shared/                     Reusable helpers
      auth.ts                    JWT verification + service client factory
      cors.ts                    Strict origin allow-list
      errors.ts                  HttpError + handle() wrapper
      rate_limit.ts              Bucket-based limiter using rate_limits table
    missions-generate/           POST /functions/v1/missions-generate
      index.ts
      gemini.ts                  Gemini 2.5 Flash call with structured output
      prompt.ts                  Prompt template
    billing-webhook/             POST /functions/v1/billing-webhook
      index.ts                   RevenueCat webhook with HMAC verification
    account-delete/              POST /functions/v1/account-delete
      index.ts                   Soft delete + auth user removal
    push-send/                   POST /functions/v1/push-send
      index.ts                   Internal-only APNs sender
```

## Local development

```sh
brew install supabase/tap/supabase
cd supabase
supabase start
supabase db reset   # applies all migrations
supabase functions serve missions-generate
```

Required local env vars (use `supabase secrets set` for cloud deployment):

```
GEMINI_API_KEY=...
REVENUECAT_WEBHOOK_SECRET=...
APNS_TEAM_ID=...
APNS_KEY_ID=...
APNS_KEY_P8=...
APP_BUNDLE_ID=com.yourdomain.OkiMission
INTERNAL_RPC_KEY=...
APPLE_SIWA_CLIENT_ID=...
APPLE_SIWA_SECRET=...
```

## Deploy

```sh
supabase link --project-ref <project-ref>
supabase db push                                 # apply migrations
supabase functions deploy missions-generate      # repeat per function
supabase functions deploy billing-webhook
supabase functions deploy account-delete
supabase functions deploy push-send
```

## Notes

- `mission_runs` is insert-only from the client side. There are no update
  or delete RLS policies on it, so a compromised client cannot rewrite
  history. Updates are reserved for the service role.
- The `update_streak(date)` RPC runs `for update` so concurrent successful
  missions cannot double-count.
- `cleanup_old_generations` and `cleanup_old_rate_limits` are wired to
  pg_cron in `20260601000005_initial_cron.sql`. If the Supabase project
  does not enable pg_cron, drop that migration and run the procedures from
  an external scheduler instead.
- The Gemini prompt schema in `missions-generate/gemini.ts` mirrors the
  parameter structs in `Sources/OkiMissionCore/MissionParameters.swift`.
  When you add a new mission kind, update both sides.
