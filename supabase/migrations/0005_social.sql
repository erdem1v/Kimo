-- 0005 — Sosyal katman: aranabilir profil görünümü + karşılıklı arkadaşlık
-- Supabase → SQL Editor'da çalıştır.
--
-- NOT: public.profiles tablosu ilk şemada zaten var (display_name, xp, streak).
-- Burada ona nickname/mascot ekliyoruz. Tabloyu HERKESE AÇMIYORUZ; içinde
-- is_minor / guardian_consent gibi hassas alanlar var. Arama ve liderlik için
-- yalnızca güvenli kolonları gösteren profiles_public görünümünü kullanıyoruz.

-- ------------------------------------------------- profiles: yeni kolonlar
alter table public.profiles
  add column if not exists nickname   text,
  add column if not exists mascot     text,
  add column if not exists updated_at timestamptz not null default now();

-- Mevcut kullanıcılar için takma adı display_name'den doldur.
update public.profiles
set nickname = coalesce(nickname, display_name, 'Öğrenci')
where nickname is null;

-- Büyük/küçük harf duyarsız arama için.
create index if not exists profiles_nickname_lower_idx
  on public.profiles (lower(nickname));

-- Upsert edebilmek için kendi satırını ekleme izni (trigger'ı ıskalayan
-- eski hesaplar için).
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check (auth.uid() = id);

-- Yeni kullanıcıda nickname de dolsun.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, nickname)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', 'Öğrenci'),
    coalesce(new.raw_user_meta_data->>'nickname',
             new.raw_user_meta_data->>'display_name', 'Öğrenci')
  );
  return new;
end;
$$;

-- ------------------------------------------- herkese açık profil görünümü
-- security_invoker = false: görünüm sahibinin yetkisiyle çalışır, yani
-- profiles üzerindeki RLS'i aşar ama SADECE aşağıdaki kolonları gösterir.
drop view if exists public.profiles_public;
create view public.profiles_public
  with (security_invoker = false)
  as select id, nickname, mascot, xp, streak from public.profiles;

grant select on public.profiles_public to authenticated;

-- ------------------------------------------------------------ friendships
create table if not exists public.friendships (
  requester_id uuid not null references auth.users(id) on delete cascade,
  addressee_id uuid not null references auth.users(id) on delete cascade,
  status       text not null default 'pending'
               check (status in ('pending', 'accepted')),
  created_at   timestamptz not null default now(),
  primary key (requester_id, addressee_id),
  constraint friendships_no_self check (requester_id <> addressee_id)
);

create index if not exists friendships_addressee_idx
  on public.friendships (addressee_id, status);
create index if not exists friendships_requester_idx
  on public.friendships (requester_id, status);

alter table public.friendships enable row level security;

-- Taraflardan biriysen görürsün.
drop policy if exists friendships_select_own on public.friendships;
create policy friendships_select_own on public.friendships
  for select to authenticated
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

-- İsteği yalnızca kendi adına gönderebilirsin.
drop policy if exists friendships_insert_own on public.friendships;
create policy friendships_insert_own on public.friendships
  for insert to authenticated with check (auth.uid() = requester_id);

-- Kabul etmeyi yalnızca isteği ALAN yapabilir.
drop policy if exists friendships_update_addressee on public.friendships;
create policy friendships_update_addressee on public.friendships
  for update to authenticated
  using (auth.uid() = addressee_id)
  with check (auth.uid() = addressee_id);

-- İsteği iptal / arkadaşlığı silme: her iki taraf da yapabilir.
drop policy if exists friendships_delete_own on public.friendships;
create policy friendships_delete_own on public.friendships
  for delete to authenticated
  using (auth.uid() = requester_id or auth.uid() = addressee_id);
