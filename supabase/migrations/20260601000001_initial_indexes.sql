-- Indexes for OkiMission. Keep these in a separate migration so adding a new
-- index later is a clean diff.

begin;

-- profiles: subscription tier scans for cohort analytics
create index profiles_active_subscribers_idx
    on public.profiles (subscription_tier)
    where deleted_at is null and subscription_tier <> 'free';

-- mission_runs: user-scoped time-ordered queries dominate
create index mission_runs_user_recent_idx
    on public.mission_runs (user_id, started_at desc);

create index mission_runs_user_kind_recent_idx
    on public.mission_runs (user_id, mission_kind, started_at desc);

create index mission_runs_outcome_idx
    on public.mission_runs (user_id, outcome, started_at desc)
    where outcome = 'success';

-- mission_generations: lookup-by-date is the hot path; expiry cleanup uses
-- the expires_at index.
create index mission_generations_user_date_idx
    on public.mission_generations (user_id, target_date desc);

create index mission_generations_expires_at_idx
    on public.mission_generations (expires_at);

-- billing_events: unprocessed events for reconciliation jobs
create index billing_events_unprocessed_idx
    on public.billing_events (received_at)
    where processed_at is null;

create index billing_events_app_user_idx
    on public.billing_events (rc_app_user_id, received_at desc);

-- rate_limits: prune expired windows efficiently
create index rate_limits_window_idx
    on public.rate_limits (window_start);

-- apple_revoke_queue: workers grab the oldest unfinished entries
create index apple_revoke_queue_pending_idx
    on public.apple_revoke_queue (enqueued_at)
    where completed_at is null;

commit;
