-- AI YKS Coach — Supabase şeması (v1)
-- Supabase Dashboard → SQL Editor'a yapıştırıp "Run" ile çalıştır.
-- Kapsam: auth'a bağlı profiller + gamification, hata bankası, özel foto deposu.
-- (Soru bankası / tekrar kuralları bilinçli olarak yok — onları sonra ekleriz.)

-- 1) Hata türü enum'u ---------------------------------------------------------
create type public.mistake_type as enum
  ('kavram_eksikligi', 'islem_hatasi', 'dikkatsizlik');

-- 2) Profiller (auth.users'a bağlı) + gamification ----------------------------
create table public.profiles (
  id                uuid primary key references auth.users(id) on delete cascade,
  display_name      text,
  exam_track        text,                       -- 'TYT' | 'AYT'
  grade             text,
  is_minor          boolean not null default true,
  guardian_consent  boolean not null default false,
  xp                int  not null default 0,
  streak            int  not null default 0,
  hearts            int  not null default 5,
  gems              int  not null default 0,
  last_activity_date date,
  created_at        timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Kendi profilini gör"
  on public.profiles for select using (auth.uid() = id);
create policy "Kendi profilini güncelle"
  on public.profiles for update using (auth.uid() = id);

-- Yeni kullanıcı kaydolunca otomatik profil oluştur
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', 'Öğrenci'));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 3) Hata bankası -------------------------------------------------------------
create table public.mistakes (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid()
                  references auth.users(id) on delete cascade,
  subject       text not null,
  concept       text not null,
  mistake_type  public.mistake_type not null,
  note          text,
  photo_path    text,               -- 'mistake-photos' bucket'ındaki yol (user_id/uuid.jpg)
  created_at    timestamptz not null default now()
);

alter table public.mistakes enable row level security;

create policy "Kendi hatalarını gör"
  on public.mistakes for select using (auth.uid() = user_id);
create policy "Kendi hatanı ekle"
  on public.mistakes for insert with check (auth.uid() = user_id);
create policy "Kendi hatanı güncelle"
  on public.mistakes for update using (auth.uid() = user_id);
create policy "Kendi hatanı sil"
  on public.mistakes for delete using (auth.uid() = user_id);

create index mistakes_user_created_idx
  on public.mistakes (user_id, created_at desc);

-- 4) Fotoğraf deposu (ÖZEL / private bucket) ----------------------------------
insert into storage.buckets (id, name, public)
values ('mistake-photos', 'mistake-photos', false)
on conflict (id) do nothing;

-- Kullanıcı yalnızca kendi klasörüne (user_id/...) erişebilir
create policy "Kendi fotolarını yükle"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'mistake-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "Kendi fotolarını gör"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'mistake-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "Kendi fotolarını sil"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'mistake-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
