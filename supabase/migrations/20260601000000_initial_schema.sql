-- OkiMission initial schema (SchemaV1)
-- All tables live in the `public` schema; `auth.users` is managed by Supabase.

begin;

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- =========================================================================
-- profiles
-- One row per authenticated user. `id` mirrors auth.users.id so RLS can use
-- auth.uid() directly for ownership checks.
-- =========================================================================
create table public.profiles (
    id                          uuid primary key references auth.users(id) on delete cascade,
    display_name                text,
    avatar_remote_url           text,
    subscription_tier           text not null default 'free' check (subscription_tier in ('free', 'pro')),
    subscription_expires_at     timestamptz,
    streak_count                int not null default 0 check (streak_count >= 0),
    longest_streak              int not null default 0 check (longest_streak >= 0),
    last_success_date           date,
    current_streak_start_date   date,
    preferred_locale            text not null default 'ja-JP',
    apns_token                  text,
    apns_env                    text check (apns_env is null or apns_env in ('sandbox', 'production')),
    created_at                  timestamptz not null default now(),
    updated_at                  timestamptz not null default now(),
    deleted_at                  timestamptz
);

-- =========================================================================
-- mission_generations
-- Server-side cache of Gemini-generated mission templates keyed by user +
-- target date + difficulty hint. We never store generated content for users
-- who have been soft-deleted.
-- =========================================================================
create table public.mission_generations (
    id                  uuid primary key default uuid_generate_v4(),
    user_id             uuid not null references public.profiles(id) on delete cascade,
    target_date         date not null,
    difficulty_hint     text not null check (difficulty_hint in ('easy', 'medium', 'hard')),
    template            jsonb not null,
    generated_at        timestamptz not null default now(),
    expires_at          timestamptz not null default (now() + interval '30 days'),
    unique (user_id, target_date, difficulty_hint)
);

-- =========================================================================
-- mission_runs
-- Append-only log of completed (or attempted) mission runs. Used for
-- analytics, leaderboard (Phase 2), and anti-cheat review.
-- =========================================================================
create table public.mission_runs (
    id                  uuid primary key default uuid_generate_v4(),
    user_id             uuid not null references public.profiles(id) on delete cascade,
    alarm_id            uuid,
    template_id         uuid,
    mission_kind        text not null check (mission_kind in ('pushup','squat','math','shake','objectHunt','barcode')),
    started_at          timestamptz not null,
    completed_at        timestamptz,
    outcome             text not null check (outcome in ('success','failure','cancelled','cheated')),
    failure_reason      text,
    duration_seconds    double precision not null check (duration_seconds >= 0),
    reps_completed      int not null default 0 check (reps_completed >= 0),
    anti_cheat_score    int not null default 0,
    signals             jsonb,
    network_latency_ms  int,
    created_at          timestamptz not null default now()
);

-- =========================================================================
-- billing_events
-- RevenueCat webhook events, stored verbatim for audit. Processed_at marks
-- when we successfully updated profiles.subscription_tier from this event.
-- rc_event_id is unique so duplicate webhook deliveries are idempotent.
-- =========================================================================
create table public.billing_events (
    id                  uuid primary key default uuid_generate_v4(),
    rc_event_id         text not null unique,
    rc_app_user_id      uuid,
    event_type          text not null,
    product_id          text,
    raw_payload         jsonb not null,
    received_at         timestamptz not null default now(),
    processed_at        timestamptz
);

-- =========================================================================
-- rate_limits
-- Sliding-window-ish counter used by Edge Functions. (user_id, bucket,
-- window_start) is unique so the rate_limit_consume RPC can upsert safely.
-- =========================================================================
create table public.rate_limits (
    user_id         uuid not null references public.profiles(id) on delete cascade,
    bucket          text not null,
    window_start    timestamptz not null,
    count           int not null default 0,
    primary key (user_id, bucket, window_start)
);

-- =========================================================================
-- apple_revoke_queue
-- Refresh tokens to revoke on apple's auth/revoke endpoint after a user
-- requests account deletion. Workers pop entries off this queue.
-- =========================================================================
create table public.apple_revoke_queue (
    id                  uuid primary key default uuid_generate_v4(),
    user_id             uuid,
    refresh_token       text not null,
    enqueued_at         timestamptz not null default now(),
    attempted_at        timestamptz,
    completed_at        timestamptz,
    last_error          text
);

commit;
