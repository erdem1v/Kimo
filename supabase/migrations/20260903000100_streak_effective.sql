-- 0047 — Serinin tek doğrusu SUNUCUDA (Task 03, bulgu 8.1).
--
-- SORUN: `apply_progress` seriyi yalnızca ARTIRIYOR; kopan seri veritabanında
-- hiç sıfırlanmıyordu. 40 gündür uygulamayı açmayan kullanıcı arkadaş
-- listesinde hâlâ 40 günlük seriyle görünüyordu. İstemcide bir görüntüleme
-- maskesi vardı ama o da bozuktu: `applyServerTotals` sunucudan gelen ham
-- `streak > 0` değerini "bugün aktifmiş" sayıp maskeyi deviriyordu.
--
-- ÇÖZÜM: yazma yolu DEĞİŞMİYOR (`apply_progress` boşluk görünce zaten 1'e
-- döndürüyor; ayrıca gece yarısı koşan bir sıfırlama işine gerek yok). Seriyi
-- DIŞARI VEREN her yüzey artık "etkin seri"yi veriyor:
--
--   etkin_seri = last_activity_date >= istanbul_bugun - 1 ise streak, değilse 0
--
-- Yüzeyler: profiles_public (arkadaş listesi/profil kartı), my_league_board
-- (lig tahtası) ve my_daily_state (kendi HUD'um — 0048'de yeniden kuruluyor,
-- oradaki kapılama o dosyada).
--
-- Milestone push tetikleyicisi (0023) `profiles` TABLOSUNU okuyor, görünümleri
-- değil; `apply_progress` boşluktan dönen kullanıcıya streak=1 yazdığı için
-- bayat bir 30, tetikleyiciye hiç 30 olarak görünmez. Etkilenmiyor.

-- Sütun listesi DEĞİŞMİYOR — yalnızca streak ifadesi — bu yüzden
-- `create or replace` yeterli.
create or replace view public.profiles_public
with (security_invoker = false) as
select
  p.id,
  p.nickname,
  p.mascot,
  p.xp,
  case when p.last_activity_date >= public.istanbul_day() - 1
       then p.streak else 0 end as streak,
  p.league,
  case when p.week_start = (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date
       then p.weekly_xp else 0 end as weekly_xp,
  case
    when p.id = auth.uid() or public.are_friends(p.id, auth.uid())
      then p.avatar_path
    else null
  end as avatar_path,
  (
    select count(*)::int from public.friendships f
     where f.status = 'accepted'
       and (f.requester_id = p.id or f.addressee_id = p.id)
  ) as friend_count
from public.profiles p
where not p.is_system
  and not p.is_anonymous;

-- `create or replace view` grant'ları korur ama yine de beyan ediyoruz:
-- görünüm yalnızca oturumlu kullanıcıya açık.
revoke all on public.profiles_public from public, anon;
grant select on public.profiles_public to authenticated;

-- ------------------------------------------------------------ lig tahtası
-- İmza ve dönüş tipi aynı; yalnızca p.streak → etkin seri.
create or replace function public.my_league_board()
returns table (
  user_id     uuid,
  nickname    text,
  mascot      text,
  xp          int,
  streak      int,
  tier        text,
  members     int,
  week_start  date,
  avatar_path text
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
    select m.user_id, p.nickname, p.mascot, m.xp,
           case when p.last_activity_date >= public.istanbul_day() - 1
                then p.streak else 0 end,
           c.tier,
           (select count(*)::int from public.league_members x
             where x.cohort_id = v_cohort),
           c.week_start,
           p.avatar_path
      from public.league_members m
      join public.profiles p on p.id = m.user_id
      join public.league_cohorts c on c.id = m.cohort_id
     where m.cohort_id = v_cohort
     order by m.xp desc, p.nickname asc;
end;
$$;

-- Postgres her CREATE OR REPLACE'te PUBLIC'e EXECUTE geri verir; hijyen
-- deseni (0033) gereği yeniden kapatıyoruz.
revoke execute on function public.my_league_board() from public, anon;
grant execute on function public.my_league_board() to authenticated;
