-- 0019 — Grup boyutu 15 → 12
-- Supabase → SQL Editor'da çalıştır.

create or replace function public.ensure_league_membership()
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_week   date := (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date;
  v_tier   text;
  v_cohort uuid;
  v_xp     int;
begin
  if v_uid is null then
    return null;
  end if;

  perform public.settle_past_leagues();

  select league,
         case when week_start = v_week then weekly_xp else 0 end
    into v_tier, v_xp
    from public.profiles where id = v_uid;
  if v_tier is null then
    return null;
  end if;

  select m.cohort_id into v_cohort
    from public.league_members m
    join public.league_cohorts c on c.id = m.cohort_id
   where m.user_id = v_uid and c.week_start = v_week
   limit 1;
  if v_cohort is not null then
    return v_cohort;
  end if;

  perform pg_advisory_xact_lock(hashtext(v_tier || v_week::text));

  select c.id into v_cohort
    from public.league_cohorts c
   where c.tier = v_tier and c.week_start = v_week
     and (select count(*) from public.league_members m where m.cohort_id = c.id) < 12
   order by c.created_at
   limit 1;

  if v_cohort is null then
    insert into public.league_cohorts (tier, week_start)
    values (v_tier, v_week)
    returning id into v_cohort;
  end if;

  insert into public.league_members (cohort_id, user_id, xp)
  values (v_cohort, v_uid, coalesce(v_xp, 0))
  on conflict do nothing;

  return v_cohort;
end;
$$;
