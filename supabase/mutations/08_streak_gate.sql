-- test: supabase/tests/200_streak_gate.sql
--
-- MUTASYON: profiles_public'i seri kapılaması OLMADAN yeniden kur (0047
-- öncesine dön: ham p.streak dışarı sızsın).
-- BEKLENEN: 200'ün "5 gün önceki 30'luk seri BAŞKALARINA 0 görünür" iddiası
-- kırmızı.
create or replace view public.profiles_public
with (security_invoker = false) as
select
  p.id,
  p.nickname,
  p.mascot,
  p.xp,
  p.streak,
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
revoke all on public.profiles_public from public, anon;
grant select on public.profiles_public to authenticated;
-- @UNDO
-- Kapılamalı sürümü (0047) geri kur.
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
revoke all on public.profiles_public from public, anon;
grant select on public.profiles_public to authenticated;
