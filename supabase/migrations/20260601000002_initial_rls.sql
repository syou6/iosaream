-- Row-Level Security policies for OkiMission.
-- The guiding rule: a user can only read/write their own rows.
-- Service role bypasses RLS for Edge Functions and admin tasks.

begin;

alter table public.profiles               enable row level security;
alter table public.mission_generations    enable row level security;
alter table public.mission_runs           enable row level security;
alter table public.billing_events         enable row level security;
alter table public.rate_limits            enable row level security;
alter table public.apple_revoke_queue     enable row level security;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create policy "profiles_self_select"
    on public.profiles for select
    using (auth.uid() = id and deleted_at is null);

create policy "profiles_self_update"
    on public.profiles for update
    using (auth.uid() = id and deleted_at is null)
    with check (auth.uid() = id);

-- profile rows are inserted via a trigger on auth.users; users cannot insert
-- their own row directly, which keeps the auth.users <-> profiles mapping
-- correct.

-- ---------------------------------------------------------------------------
-- mission_generations
-- Read-only to the owner; writes happen via the missions-generate Edge
-- Function using the service role.
-- ---------------------------------------------------------------------------
create policy "mission_generations_self_select"
    on public.mission_generations for select
    using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- mission_runs
-- The client uploads its own runs via PostgREST.
-- ---------------------------------------------------------------------------
create policy "mission_runs_self_select"
    on public.mission_runs for select
    using (auth.uid() = user_id);

create policy "mission_runs_self_insert"
    on public.mission_runs for insert
    with check (auth.uid() = user_id);

-- We deliberately do NOT allow update or delete from the client side, so a
-- compromised app cannot rewrite history.

-- ---------------------------------------------------------------------------
-- billing_events
-- Webhook-only, service role writes, no user access.
-- ---------------------------------------------------------------------------
-- (no policies = no client access via anon/authenticated roles)

-- ---------------------------------------------------------------------------
-- rate_limits
-- Service role only.
-- ---------------------------------------------------------------------------
-- (no policies)

-- ---------------------------------------------------------------------------
-- apple_revoke_queue
-- Service role only.
-- ---------------------------------------------------------------------------
-- (no policies)

commit;
