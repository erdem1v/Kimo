-- 0024 — Profil fotoğrafı, arkadaş sayısı ve başkasının profilini görme
-- Supabase → SQL Editor'da çalıştır.
--
-- • profiles.avatar_path: Storage'daki fotoğrafın yolu (yoksa maskot simgesi)
-- • profiles_public: avatar_path ve friend_count eklendi (kolon SONA eklenir;
--   görünümü DROP edersek ona bağlı fonksiyonlar da düşer — bkz. 0016 dersi)
-- • my_league_board: listede avatar gösterebilmek için avatar_path döner

alter table public.profiles
  add column if not exists avatar_path text;

-- ------------------------------------------------------------ avatar kovası
-- Özel kova: okuma yalnızca oturum açmış kullanıcılara, yazma yalnızca kendi
-- klasörüne. Görselleri imzalı URL ile gösteriyoruz (soru fotoğraflarındaki
-- yaklaşımın aynısı).
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do nothing;

-- Avatarlar listelerde herkese görünür (lig, arkadaşlar, arama).
drop policy if exists "avatars readable" on storage.objects;
create policy "avatars readable" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars');

-- Yazma/güncelleme/silme yalnızca kendi klasöründe: avatars/<uid>/...
drop policy if exists "avatars insert own" on storage.objects;
create policy "avatars insert own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars update own" on storage.objects;
create policy "avatars update own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars delete own" on storage.objects;
create policy "avatars delete own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ------------------------------------------------------- açık profil görünümü
-- Mevcut kolonların adı/sırası/tipi AYNEN korunur; yeni kolonlar sona eklenir.
-- Böylece görünüme bağlı fonksiyonlar (random_public_questions vb.) bozulmaz.
create or replace view public.profiles_public
  with (security_invoker = false)
  as select
       p.id, p.nickname, p.mascot, p.xp, p.streak, p.league,
       case
         when p.week_start = (date_trunc('week',
                now() at time zone 'Europe/Istanbul'))::date
           then p.weekly_xp
         else 0
       end as weekly_xp,
       p.avatar_path,
       (select count(*)::int
          from public.friendships f
         where f.status = 'accepted'
           and (f.requester_id = p.id or f.addressee_id = p.id)
       ) as friend_count
     from public.profiles p;

grant select on public.profiles_public to authenticated;

-- --------------------------------------------------------------- lig listesi
-- Dönüş tipi değiştiği için önce düşürülmeli (create or replace yetmez).
drop function if exists public.my_league_board();

create function public.my_league_board()
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
    select m.user_id, p.nickname, p.mascot, m.xp, p.streak,
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

grant execute on function public.my_league_board() to authenticated;
