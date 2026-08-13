-- 0017 — Gerçek lig yarışı: 15 kişilik gruplar, haftalık ilk 5 üst lige
-- Supabase → SQL Editor'da çalıştır.
--
-- ÖNCEKİ MODEL: lig toplam XP eşiğinden türetiliyordu (generated column).
-- Kimseyle yarışmıyordun, XP biriktikçe otomatik yükseliyordun.
--
-- YENİ MODEL: her hafta aynı ligdeki oyuncular 15 kişilik gruplara bölünür.
-- Hafta sonunda grubun haftalık XP sıralamasında İLK 5 üst lige çıkar.
-- Terfi yalnızca sıralamayla olur; XP eşiği kalktı.
--
-- Haftalık kapanış için zamanlanmış işe (cron) gerek yok: geçmiş haftalar,
-- biri ligini ilk açtığında bir kez ve toplu olarak sonuçlandırılır.

-- ---------------------------------------------------------------- şema
-- profiles_public, league kolonunu gösteriyor; kolonu değiştirmek için önce
-- görünümü düşürmemiz gerekiyor (fonksiyon bağımlılığı yok, güvenli).
drop view if exists public.profiles_public;

alter table public.profiles drop column if exists league;
alter table public.profiles
  add column if not exists league text not null default 'bronz'
    check (league in ('bronz', 'gumus', 'altin', 'elmas', 'efsane'));

-- Mevcut kullanıcılar ligsiz kalmasın: eski eşiklerle bir kereliğine yerleştir.
update public.profiles
   set league = case
                  when xp >= 7500 then 'efsane'
                  when xp >= 3500 then 'elmas'
                  when xp >= 1500 then 'altin'
                  when xp >=  500 then 'gumus'
                  else 'bronz'
                end;

create index if not exists profiles_league_idx on public.profiles (league);

create table if not exists public.league_cohorts (
  id         uuid primary key default gen_random_uuid(),
  tier       text not null,
  week_start date not null,
  settled_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists league_cohorts_week_idx
  on public.league_cohorts (week_start, tier);

create table if not exists public.league_members (
  cohort_id uuid not null references public.league_cohorts(id) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  xp        int  not null default 0,   -- o haftaki XP (hafta kapanınca donar)
  primary key (cohort_id, user_id)
);

create index if not exists league_members_user_idx
  on public.league_members (user_id);

alter table public.league_cohorts enable row level security;
alter table public.league_members enable row level security;

-- Okuma serbest (liderlik tablosu); yazma yalnızca aşağıdaki fonksiyonlarla.
drop policy if exists cohorts_select on public.league_cohorts;
create policy cohorts_select on public.league_cohorts
  for select to authenticated using (true);

drop policy if exists members_select on public.league_members;
create policy members_select on public.league_members
  for select to authenticated using (true);

-- Haftalık XP değişince grup kaydı da güncellensin.
create or replace function public.sync_league_member_xp()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.weekly_xp is distinct from old.weekly_xp then
    update public.league_members m
       set xp = new.weekly_xp
      from public.league_cohorts c
     where m.user_id = new.id
       and m.cohort_id = c.id
       and c.settled_at is null
       and c.week_start = (date_trunc('week',
             now() at time zone 'Europe/Istanbul'))::date;
  end if;
  return new;
end;
$$;

drop trigger if exists on_profile_weekly_xp on public.profiles;
create trigger on_profile_weekly_xp
  after update on public.profiles
  for each row execute function public.sync_league_member_xp();

-- ------------------------------------------------------- hafta kapanışı
-- Geçmiş haftaların gruplarını sonuçlandırır: her grupta haftalık XP'ye göre
-- İLK 5 (ve XP'si sıfırdan büyük olanlar) bir üst lige çıkar.
create or replace function public.settle_past_leagues()
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_week date := (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date;
begin
  -- Terfi edenler
  update public.profiles p
     set league = case p.league
                    when 'bronz'  then 'gumus'
                    when 'gumus'  then 'altin'
                    when 'altin'  then 'elmas'
                    when 'elmas'  then 'efsane'
                    else 'efsane'   -- en üst ligde kalır
                  end
    from (
      select m.user_id
        from public.league_members m
        join public.league_cohorts c on c.id = m.cohort_id
       where c.settled_at is null
         and c.week_start < v_week
         and m.xp > 0
         and (
           select count(*) from public.league_members m2
            where m2.cohort_id = m.cohort_id
              and (m2.xp > m.xp or (m2.xp = m.xp and m2.user_id < m.user_id))
         ) < 5
    ) promoted
   where p.id = promoted.user_id;

  -- Grupları kapat
  update public.league_cohorts
     set settled_at = now()
   where settled_at is null
     and week_start < v_week;
end;
$$;

-- --------------------------------------------------- gruba yerleştirme
-- Kullanıcıyı bu haftanın grubuna koyar; grup yoksa ya da doluysa yenisini
-- açar. Aynı anda gelen isteklerin grubu taşırmaması için kilit kullanılır.
create or replace function public.ensure_league_membership()
returns uuid
language plpgsql security definer set search_path = public
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

  -- Bu hafta zaten bir gruptaysa onu döndür.
  select m.cohort_id into v_cohort
    from public.league_members m
    join public.league_cohorts c on c.id = m.cohort_id
   where m.user_id = v_uid and c.week_start = v_week
   limit 1;
  if v_cohort is not null then
    return v_cohort;
  end if;

  -- Aynı lig+hafta için sıraya girerken kilitle (grup 15'i aşmasın).
  perform pg_advisory_xact_lock(hashtext(v_tier || v_week::text));

  select c.id into v_cohort
    from public.league_cohorts c
   where c.tier = v_tier and c.week_start = v_week
     and (select count(*) from public.league_members m where m.cohort_id = c.id) < 15
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

grant execute on function public.ensure_league_membership() to authenticated;

-- ------------------------------------------------------ grup sıralaması
create or replace function public.my_league_board()
returns table (
  user_id   uuid,
  nickname  text,
  mascot    text,
  xp        int,
  streak    int,
  tier      text,
  members   int,
  week_start date
)
language plpgsql stable security definer set search_path = public
as $$
declare
  v_cohort uuid;
begin
  select m.cohort_id into v_cohort
    from public.league_members m
    join public.league_cohorts c on c.id = m.cohort_id
   where m.user_id = auth.uid()
     and c.week_start = (date_trunc('week',
           now() at time zone 'Europe/Istanbul'))::date
   limit 1;

  if v_cohort is null then
    return;
  end if;

  return query
    select m.user_id, p.nickname, p.mascot, m.xp, p.streak,
           c.tier,
           (select count(*)::int from public.league_members x
             where x.cohort_id = v_cohort),
           c.week_start
      from public.league_members m
      join public.profiles p on p.id = m.user_id
      join public.league_cohorts c on c.id = m.cohort_id
     where m.cohort_id = v_cohort
     order by m.xp desc, p.nickname asc;
end;
$$;

grant execute on function public.my_league_board() to authenticated;

-- --------------------------------------------- herkese açık profil görünümü
create view public.profiles_public
  with (security_invoker = false)
  as select
       id, nickname, mascot, xp, streak, league,
       case
         when week_start = (date_trunc('week',
                now() at time zone 'Europe/Istanbul'))::date
           then weekly_xp
         else 0
       end as weekly_xp
     from public.profiles;

grant select on public.profiles_public to authenticated;
