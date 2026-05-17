-- Stored procedures for OkiMission. These run with the privileges of the
-- creator (security definer) so they can mutate rows that RLS would
-- otherwise hide.

begin;

-- ---------------------------------------------------------------------------
-- handle_new_user
-- Trigger function that creates a public.profiles row whenever a row is
-- inserted into auth.users. Keeps profile creation in lockstep with sign-up
-- without requiring the client to perform a second authenticated insert.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, preferred_locale)
    values (
        new.id,
        coalesce(new.raw_user_meta_data ->> 'locale', 'ja-JP')
    )
    on conflict (id) do nothing;
    return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- update_streak
-- Atomic streak increment. Returns the new streak count. Called by clients
-- via PostgREST RPC after a successful mission run.
-- ---------------------------------------------------------------------------
create or replace function public.update_streak(p_success_date date)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();
    v_last_success date;
    v_current_streak int;
    v_longest int;
    v_streak_start date;
begin
    if v_user_id is null then
        raise exception 'not authenticated';
    end if;

    select last_success_date, streak_count, longest_streak, current_streak_start_date
        into v_last_success, v_current_streak, v_longest, v_streak_start
        from public.profiles
        where id = v_user_id
        for update;

    if v_last_success = p_success_date then
        return v_current_streak;
    elsif v_last_success = p_success_date - 1 then
        v_current_streak := v_current_streak + 1;
    else
        v_current_streak := 1;
        v_streak_start := p_success_date;
    end if;

    v_longest := greatest(v_longest, v_current_streak);

    update public.profiles
        set last_success_date = p_success_date,
            streak_count = v_current_streak,
            longest_streak = v_longest,
            current_streak_start_date = v_streak_start,
            updated_at = now()
        where id = v_user_id;

    return v_current_streak;
end;
$$;

grant execute on function public.update_streak(date) to authenticated;

-- ---------------------------------------------------------------------------
-- rate_limit_consume
-- Per-bucket counter for Edge Functions. Service role only.
-- ---------------------------------------------------------------------------
create or replace function public.rate_limit_consume(
    p_user_id uuid,
    p_bucket text,
    p_window_start timestamptz,
    p_max_count int
)
returns table (allowed boolean, remaining int)
language plpgsql
security definer
as $$
declare
    v_count int;
begin
    insert into public.rate_limits (user_id, bucket, window_start, count)
    values (p_user_id, p_bucket, p_window_start, 1)
    on conflict (user_id, bucket, window_start)
    do update set count = public.rate_limits.count + 1
    returning count into v_count;

    return query select v_count <= p_max_count, greatest(0, p_max_count - v_count);
end;
$$;

-- ---------------------------------------------------------------------------
-- soft_delete_account
-- Marks profile as deleted, anonymises identifiers, returns the apple
-- refresh token (if any) so the Edge Function can call apple revoke.
-- ---------------------------------------------------------------------------
create or replace function public.soft_delete_account()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();
    v_refresh_token text;
begin
    if v_user_id is null then
        raise exception 'not authenticated';
    end if;

    select au.raw_user_meta_data ->> 'apple_refresh_token'
        into v_refresh_token
        from auth.users au
        where au.id = v_user_id;

    update public.profiles
        set deleted_at = now(),
            display_name = null,
            avatar_remote_url = null,
            apns_token = null,
            updated_at = now()
        where id = v_user_id;

    if v_refresh_token is not null then
        insert into public.apple_revoke_queue (user_id, refresh_token)
        values (v_user_id, v_refresh_token);
    end if;

    return v_refresh_token;
end;
$$;

grant execute on function public.soft_delete_account() to authenticated;

-- ---------------------------------------------------------------------------
-- cleanup_old_generations
-- pg_cron target: removes mission_generations whose expires_at has passed.
-- ---------------------------------------------------------------------------
create or replace function public.cleanup_old_generations()
returns void
language plpgsql
security definer
as $$
begin
    delete from public.mission_generations
    where expires_at < now();
end;
$$;

-- ---------------------------------------------------------------------------
-- cleanup_old_rate_limits
-- pg_cron target: prune rate_limit rows older than 30 days.
-- ---------------------------------------------------------------------------
create or replace function public.cleanup_old_rate_limits()
returns void
language plpgsql
security definer
as $$
begin
    delete from public.rate_limits
    where window_start < now() - interval '30 days';
end;
$$;

commit;
