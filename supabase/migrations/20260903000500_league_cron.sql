-- 0051 — Lig yerleşimi zamanlanmış işe taşındı; O(N) döngü kapandı (Task 03,
-- bulgu 10.1).
--
-- SORUN: haftalık kohort dağıtımı TEMBELDİ — haftanın ilk lig-sekmesi açılışı
-- `ensure_league_membership` → `assign_week_cohorts` zincirini tetikliyordu ve
-- o fonksiyon TÜM profilleri satır satır dolaşıp her satırda iç içe bir
-- count(*) çalıştırıyordu: O(profil × kohort). Pazartesi sabahı ilk açan
-- kullanıcı bütün nüfusun yerleşimini bekliyordu (advisory lock arkasında
-- kuyruklanan diğerleriyle birlikte).
--
-- ÇÖZÜM üç parça:
--  1. `assign_week_cohorts` KÜME-TABANLI yeniden yazıldı: kalan kapasiteler
--     tek gruplu sorguyla, yeni üyeler row_number/modulo ile tek INSERT'te.
--  2. Haftalık iş pg_cron'a alındı: Pazartesi 00:05 Istanbul (pg_cron UTC
--     çalışır; Istanbul sabit UTC+3 → Pazar 21:05 UTC). Tahtalar hafta
--     başında kullanıcı beklemeden dolu.
--  3. `ensure_league_membership` UCUZ bir güvenlik ağına indi: yalnızca
--     ÇAĞIRANI yerleştirir (hafta ortası kayıt olan yeni kullanıcı), asla
--     tüm nüfusu dolaşmaz; settle yalnızca gerçekten bekleyen kohort varsa.
--
-- Aynı cron altyapısıyla iki iş daha zamanlanıyor:
--  • scan-photos süpürmesi (10 dk) — 0050'nin bekleyen taramaları
--  • cleanup-anonymous (günlük) — edge fonksiyonun başındaki "zamanlayıcı yok"
--    notunun kapanışı
-- HTTP işleri, taban adres (`app_config.edge_base_url`) ve Vault'taki
-- `service_role_key` sırrı TANIMLIYSA iş yapar; değilse sessizce no-op
-- (CI'da ve sır girilmemiş ortamda hata üretmez — kurulum adımı rapora
-- yazıldı).

-- ------------------------------------------------------------- eklentiler
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- ------------------------------------------------- küme-tabanlı dağıtım
create or replace function public.assign_week_cohorts()
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_week date := (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date;
  v_size int  := public.league_cohort_size();
begin
  -- Eşzamanlı çağrılara karşı (cron + hafta ortası fallback'ler) tek kilit.
  perform pg_advisory_xact_lock(hashtext('cohorts' || v_week::text));

  -- 1) Yerleşmemiş adaylar, lig içinde deterministik sırayla numaralanır.
  -- (Aynı işlem içinde ikinci çağrı — ör. test süiti — için önce temizlik:
  -- ON COMMIT DROP işlem bitene dek tabloyu tutar.)
  drop table if exists pg_temp._pending;
  drop table if exists pg_temp._seats;
  drop table if exists pg_temp._overflow;
  drop table if exists pg_temp._new_cohorts;
  create temp table _pending on commit drop as
    select p.id,
           p.league,
           case when p.week_start = v_week then p.weekly_xp else 0 end as xp,
           row_number() over (partition by p.league order by p.id) - 1 as seq
      from public.profiles p
     where not p.is_anonymous
       and not p.is_system
       and not exists (
         select 1
           from public.league_members m
           join public.league_cohorts c on c.id = m.cohort_id
          where m.user_id = p.id and c.week_start = v_week
       );

  if not exists (select 1 from _pending) then
    return;
  end if;

  -- 2) Bu haftanın mevcut kohortlarındaki BOŞ koltuklar (hafta ortası koşumda
  --    dolu olabilirler; Pazartesi cron'unda bu küme boştur). Koltuklar tek
  --    gruplu sorguyla sayılır — satır başına count yok.
  create temp table _seats on commit drop as
    select tier,
           cohort_id,
           row_number() over (partition by tier
                              order by created_at, seat_no) - 1 as seat_seq
      from (
        select c.tier, c.id as cohort_id, c.created_at,
               generate_series(1, v_size - x.n) as seat_no
          from public.league_cohorts c
          join lateral (
            select count(*)::int as n
              from public.league_members m
             where m.cohort_id = c.id
          ) x on true
         where c.week_start = v_week
           and x.n < v_size
      ) seats;

  -- 3) Önce boş koltuklar doldurulur (seq ↔ seat_seq eşleşmesi)…
  insert into public.league_members (cohort_id, user_id, xp)
  select s.cohort_id, p.id, coalesce(p.xp, 0)
    from _pending p
    join _seats s on s.tier = p.league and s.seat_seq = p.seq
  on conflict do nothing;

  -- 4) …koltuk bulamayanlar v_size'lık YENİ kohortlara modulo ile dağıtılır.
  create temp table _overflow on commit drop as
    select p.id, p.league, p.xp,
           row_number() over (partition by p.league order by p.seq) - 1 as oseq
      from _pending p
      left join _seats s on s.tier = p.league and s.seat_seq = p.seq
     where s.cohort_id is null;

  create temp table _new_cohorts on commit drop as
    select gen_random_uuid() as id, league, grp
      from (
        select distinct league, (oseq / v_size) as grp from _overflow
      ) g;

  insert into public.league_cohorts (id, tier, week_start)
  select id, league, v_week from _new_cohorts;

  insert into public.league_members (cohort_id, user_id, xp)
  select nc.id, o.id, coalesce(o.xp, 0)
    from _overflow o
    join _new_cohorts nc
      on nc.league = o.league and nc.grp = (o.oseq / v_size)
  on conflict do nothing;
end;
$$;

revoke execute on function public.assign_week_cohorts()
  from public, anon, authenticated;

-- ---------------------------------------------- ucuz tek-kullanıcı fallback
create or replace function public.ensure_league_membership()
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_week   date := (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date;
  v_size   int  := public.league_cohort_size();
  v_tier   text;
  v_cohort uuid;
  v_xp     int;
begin
  if v_uid is null then
    return null;
  end if;

  -- Geçen haftanın hesabı yalnızca GERÇEKTEN bekleyen kohort varsa görülür;
  -- cron koştuysa bu no-op maliyetindedir.
  if exists (
    select 1 from public.league_cohorts
     where settled_at is null and week_start < v_week
  ) then
    perform public.settle_past_leagues();
  end if;

  select m.cohort_id into v_cohort
    from public.league_members m
    join public.league_cohorts c on c.id = m.cohort_id
   where m.user_id = v_uid and c.week_start = v_week
   limit 1;
  if v_cohort is not null then
    return v_cohort;
  end if;

  -- Anonim/sistem hesabı kohorta girmez (0046 kararı).
  select p.league,
         case when p.week_start = v_week then p.weekly_xp else 0 end
    into v_tier, v_xp
    from public.profiles p
   where p.id = v_uid and not p.is_anonymous and not p.is_system;
  if v_tier is null then
    return null;
  end if;

  -- YALNIZCA ÇAĞIRAN yerleştirilir. Eski sürüm burada assign_week_cohorts ile
  -- bütün nüfusu dolaşıyordu — bir kullanıcının sekme açılışı O(N) işti.
  perform pg_advisory_xact_lock(hashtext(v_tier || v_week::text));

  select c.id into v_cohort
    from public.league_cohorts c
   where c.tier = v_tier and c.week_start = v_week
     and (select count(*) from public.league_members m
           where m.cohort_id = c.id) < v_size
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

revoke execute on function public.ensure_league_membership() from public, anon;
grant  execute on function public.ensure_league_membership() to authenticated;

-- --------------------------------------------------------- haftalık iş
create or replace function public.league_weekly_rollover()
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  perform public.settle_past_leagues();
  perform public.assign_week_cohorts();
end;
$$;

-- Yalnızca pg_cron (job sahibi postgres) çağırır; kullanıcıya açılsaydı
-- herkes yerleşimi istediği an tetikleyebilirdi.
revoke execute on function public.league_weekly_rollover()
  from public, anon, authenticated;

-- ------------------------------------------------------------ zamanlama
-- Yeniden çalıştırılabilir: aynı adla iş varsa önce kaldırılır.
do $cron$
begin
  perform cron.unschedule(jobid)
    from cron.job
   where jobname in ('league-weekly-rollover', 'scan-photos-sweep',
                     'cleanup-anonymous-daily');
exception when others then
  null; -- ilk kurulumda tablo boş; sorun değil
end
$cron$;

-- Pazartesi 00:05 Istanbul = Pazar 21:05 UTC (pg_cron UTC çalışır; Istanbul
-- DST uygulamıyor, sabit +3).
select cron.schedule(
  'league-weekly-rollover',
  '5 21 * * 0',
  $$select public.league_weekly_rollover()$$
);

-- Fotoğraf taraması süpürmesi (0050): elle giriş / çökmüş istemci / çevrimdışı
-- kuyruk satırları 10 dakikada bir taranır. Taban adres ve servis sırrı
-- girilmemişse sorgu no-op — hata üretmez, iş görünür kalır.
select cron.schedule(
  'scan-photos-sweep',
  '*/10 * * * *',
  $$
  select net.http_post(
           url := (select value from public.app_config
                    where key = 'edge_base_url') || '/scan-photos',
           headers := jsonb_build_object(
             'Authorization',
             'Bearer ' || (select decrypted_secret
                             from vault.decrypted_secrets
                            where name = 'service_role_key'),
             'Content-Type', 'application/json'),
           body := '{}'::jsonb)
   where exists (select 1 from public.app_config where key = 'edge_base_url')
     and exists (select 1 from vault.decrypted_secrets
                  where name = 'service_role_key')
     and exists (select 1 from public.mistakes
                  where photo_scan = 'pending' and photo_path is not null)
  $$
);

-- Anonim hesap temizliği (0046 fonksiyonunun eksik zamanlayıcısı): her gece
-- 01:30 Istanbul = 22:30 UTC.
select cron.schedule(
  'cleanup-anonymous-daily',
  '30 22 * * *',
  $$
  select net.http_post(
           url := (select value from public.app_config
                    where key = 'edge_base_url') || '/cleanup-anonymous',
           headers := jsonb_build_object(
             'Authorization',
             'Bearer ' || (select decrypted_secret
                             from vault.decrypted_secrets
                            where name = 'service_role_key'),
             'Content-Type', 'application/json'),
           body := '{}'::jsonb)
   where exists (select 1 from public.app_config where key = 'edge_base_url')
     and exists (select 1 from vault.decrypted_secrets
                  where name = 'service_role_key')
  $$
);
