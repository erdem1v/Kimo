-- 0020 — Gruplar herkesi kapsasın
-- Supabase → SQL Editor'da çalıştır.
--
-- SORUN: gruba yerleştirme tembeldi — kullanıcı lig sekmesini açtığında
-- yapılıyordu. Kayıtlı 9 kişi olsa da yalnızca sekmeyi açanlar gruba giriyor,
-- geri kalan görünmüyordu; herkes kendi başına kalıyordu.
--
-- ÇÖZÜM: haftanın grupları ilk açılışta TOPLU kurulur. Kim uygulamayı açarsa
-- açsın, o haftanın tüm kullanıcıları ligleri içinde 12'lik gruplara dağıtılır.
-- Böylece sıralama ilk andan itibaren dolu görünür; hiç çözmeyenler 0 XP ile
-- en altta yer alır ve hafta sonunda düşme bölgesine girer.

create or replace function public.assign_week_cohorts()
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_week   date := (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date;
  v_cohort uuid;
  r        record;
begin
  for r in
    select p.id,
           p.league,
           case when p.week_start = v_week then p.weekly_xp else 0 end as xp
      from public.profiles p
     where not exists (
       select 1
         from public.league_members m
         join public.league_cohorts c on c.id = m.cohort_id
        where m.user_id = p.id and c.week_start = v_week
     )
     order by p.league, p.id
  loop
    -- Aynı ligde yeri olan grubu bul; yoksa yeni grup aç.
    select c.id into v_cohort
      from public.league_cohorts c
     where c.tier = r.league
       and c.week_start = v_week
       and (select count(*) from public.league_members m
             where m.cohort_id = c.id) < 12
     order by c.created_at
     limit 1;

    if v_cohort is null then
      insert into public.league_cohorts (tier, week_start)
      values (r.league, v_week)
      returning id into v_cohort;
    end if;

    insert into public.league_members (cohort_id, user_id, xp)
    values (v_cohort, r.id, coalesce(r.xp, 0))
    on conflict do nothing;
  end loop;
end;
$$;

-- Artık kullanıcıya özel yerleştirme yerine toplu dağıtım çağrılıyor.
create or replace function public.ensure_league_membership()
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_week   date := (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date;
  v_cohort uuid;
begin
  if v_uid is null then
    return null;
  end if;

  perform public.settle_past_leagues();

  -- Zaten bu haftanın grubundaysam dağıtımı tekrar çalıştırma.
  select m.cohort_id into v_cohort
    from public.league_members m
    join public.league_cohorts c on c.id = m.cohort_id
   where m.user_id = v_uid and c.week_start = v_week
   limit 1;
  if v_cohort is not null then
    return v_cohort;
  end if;

  -- Eşzamanlı açılışlarda grupların bozulmaması için kilit.
  perform pg_advisory_xact_lock(hashtext('cohorts' || v_week::text));
  perform public.assign_week_cohorts();

  select m.cohort_id into v_cohort
    from public.league_members m
    join public.league_cohorts c on c.id = m.cohort_id
   where m.user_id = v_uid and c.week_start = v_week
   limit 1;

  return v_cohort;
end;
$$;
