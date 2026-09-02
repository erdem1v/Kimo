-- 0006 — Lig yarışı: haftalık XP + lig kademesi
-- Supabase → SQL Editor'da çalıştır.
--
-- Toplam XP lig kademesini belirler (generated column: her zaman tutarlı).
-- Haftalık XP ise lig içindeki sıralamayı belirler ve her pazartesi sıfırlanır.
-- Sıfırlama için zamanlanmış işe gerek yok: görünüm, haftası geçmiş kayıtların
-- haftalık XP'sini 0 gösterir.

alter table public.profiles
  add column if not exists weekly_xp  int not null default 0,
  add column if not exists week_start date;

-- Lig kademesi toplam XP'den türetilir; elle güncellenemez, hep doğrudur.
alter table public.profiles
  add column if not exists league text generated always as (
    case
      when xp >= 7500 then 'efsane'
      when xp >= 3500 then 'elmas'
      when xp >= 1500 then 'altin'
      when xp >=  500 then 'gumus'
      else 'bronz'
    end
  ) stored;

create index if not exists profiles_league_weekly_idx
  on public.profiles (league, weekly_xp desc);

-- Görünümü yeni kolonlarla tazele. Haftası geçmiş weekly_xp 0 gösterilir ki
-- sıralama geçen haftanın puanıyla bozulmasın.
drop view if exists public.profiles_public;
create view public.profiles_public
  with (security_invoker = false)
  as select
       id,
       nickname,
       mascot,
       xp,
       streak,
       league,
       case
         when week_start = (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date
           then weekly_xp
         else 0
       end as weekly_xp
     from public.profiles;

grant select on public.profiles_public to authenticated;
