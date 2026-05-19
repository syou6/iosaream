-- pg_cron schedules for OkiMission.
-- Requires the `pg_cron` extension to be enabled in the Supabase project.

begin;

create extension if not exists pg_cron;

-- Daily cleanup of expired Gemini cache entries.
select cron.schedule(
    'okimission-cleanup-generations',
    '0 3 * * *',
    $$select public.cleanup_old_generations()$$
);

-- Weekly cleanup of old rate-limit windows.
select cron.schedule(
    'okimission-cleanup-rate-limits',
    '0 4 * * 0',
    $$select public.cleanup_old_rate_limits()$$
);

commit;
