-- 0025 — Çıkmış sorular (ÖSYM) havuza
-- Supabase → SQL Editor'da çalıştır.
--
-- Havuz yeni kullanıcı için boş kalmasın diye ÖSYM çıkmış soruları da
-- yükleyeceğiz. Bu sorular tek bir "sistem" hesabına aittir:
--   • mistakes.user_id NOT NULL ve auth.users'a bağlı — sahipsiz soru olamaz.
--   • public_questions görünümü profiles ile join yapıyor; künye oradan gelir.
--
-- Kurulum iki adım: önce uygulamadan bu hesabı aç, sonra aşağıdaki
-- set_osym_account() ile işaretle (en altta anlatılıyor).

-- ------------------------------------------------------- sorunun kaynağı
alter table public.mistakes
  add column if not exists source         text not null default 'user',
  add column if not exists source_year    int,
  add column if not exists source_session text;

-- Yalnızca bildiğimiz kaynaklar. Yeni kaynak eklenirse kısıt güncellenir.
alter table public.mistakes
  drop constraint if exists mistakes_source_check;
alter table public.mistakes
  add constraint mistakes_source_check
  check (source in ('user', 'osym', 'meb'));

comment on column public.mistakes.source is
  'user = kullanıcının kendi hatası · osym = ÖSYM çıkmış sorusu · meb = MEB kazanım testi';
comment on column public.mistakes.source_year is
  'Hazır soruysa kaynağın yılı (ör. 2026)';
comment on column public.mistakes.source_session is
  'Hazır soruysa alt küme (ör. TYT, AYT, Kazanım Testi)';

create index if not exists mistakes_source_idx
  on public.mistakes (source, source_year) where source <> 'user';

-- ------------------------------------------------------------ sistem hesabı
-- Bu hesap arama sonuçlarında, arkadaş listelerinde ve ligde görünmemeli:
-- o bir öğrenci değil, soruların taşıyıcısı.
alter table public.profiles
  add column if not exists is_system boolean not null default false;

-- ---------------------------------------------------- açık profil görünümü
-- Kolon adları/sırası/tipleri 0024'teki gibi AYNEN korunur (görünümü DROP
-- edersek ona bağlı fonksiyonlar da düşer); yalnızca sistem hesapları elenir.
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
     from public.profiles p
    where not p.is_system;

grant select on public.profiles_public to authenticated;

-- ------------------------------------------------------- havuz görünümü
-- Mevcut kolonlar aynen kalır; kaynak bilgisi SONA eklenir. Böylece
-- random_public_questions / random_questions_by_topic bozulmaz.
create or replace view public.public_questions
  with (security_invoker = false)
  as select
       m.id,
       m.user_id       as owner_id,
       p.nickname      as owner_nickname,
       m.subject,
       m.concept,
       m.exam,
       m.photo_path,
       m.options,
       m.correct_index,
       m.solved_correct,
       m.solved_wrong,
       m.created_at,
       m.source,
       m.source_year,
       m.source_session
     from public.mistakes m
     join public.profiles p on p.id = m.user_id
     where m.is_public
       and m.moderation = 'ok'
       and m.photo_path is not null
       and m.options is not null
       and m.correct_index is not null;

grant select on public.public_questions to authenticated;

-- --------------------------------------------------- hesabı işaretleme
-- Kimliği app_config'de tutuyoruz ki içe aktarma betiği UUID'yi elle
-- taşımak zorunda kalmasın.
create or replace function public.set_osym_account(p_user uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not exists (select 1 from auth.users where id = p_user) then
    raise exception 'Böyle bir kullanıcı yok: %', p_user;
  end if;

  insert into public.app_config (key, value)
  values ('osym_user_id', p_user::text)
  on conflict (key) do update set value = excluded.value;

  update public.profiles
     set nickname  = 'ÖSYM Çıkmış Sorular',
         is_system = true
   where id = p_user;
end;
$$;

-- Yalnızca yönetici (service_role) çağırır; uygulamadan erişim yok.
revoke execute on function public.set_osym_account(uuid) from public, authenticated;

-- ---------------------------------------------------------------- KURULUM
-- 1) Uygulamadan normal bir hesap aç (ör. cikmis-sorular@ornek.com).
--    Karşılama akışını tamamlamana gerek yok, kayıt olman yeter.
-- 2) Kullanıcının kimliğini bul:
--       select id, email from auth.users order by created_at desc limit 5;
-- 3) Hesabı işaretle:
--       select public.set_osym_account('BURAYA-UUID');
-- 4) Kontrol:
--       select value from public.app_config where key = 'osym_user_id';
