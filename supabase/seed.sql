-- seed.sql — YALNIZCA YEREL / TEST. Üretime ASLA gitmez.
--
-- `supabase db reset` bunu göçlerden SONRA uygular. `supabase db push` seed
-- dosyalarını uygulamaz, dolayısıyla buradaki sahte kullanıcı üreten yardımcılar
-- üretim veritabanına hiçbir koşulda ulaşamaz.
--
-- İçerik: pgTAP eklentisi + RLS testlerinde kimliğe bürünmek için `tests` şeması.

create extension if not exists pgtap with schema extensions;

create schema if not exists tests;
grant usage on schema tests to postgres, anon, authenticated, service_role;

-- ---------------------------------------------------------------- kullanıcı üret
-- auth.users'a satır ekler; on_auth_user_created trigger'ı public.profiles
-- satırını kendisi yaratır (yani testlerde profiles'a INSERT etmeyin, UPDATE edin).
create or replace function tests.create_supabase_user(identifier text)
returns uuid
language plpgsql security definer set search_path = auth, public, pg_temp
as $$
declare v_id uuid := gen_random_uuid();
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id,
    'authenticated', 'authenticated',
    identifier || '@test.local', '', now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('test_identifier', identifier),
    now(), now()
  );
  return v_id;
end $$;

create or replace function tests.get_supabase_uid(identifier text)
returns uuid
language sql stable security definer set search_path = auth, pg_temp
as $$
  select id from auth.users
   where raw_user_meta_data->>'test_identifier' = identifier
   limit 1
$$;

-- DEFINER olmak ZORUNDA: `authenticated` rolüne geçtikten sonra auth.users
-- okunamaz, yani ikinci authenticate_as çağrısı aksi hâlde patlar.
create or replace function tests.get_supabase_user(identifier text)
returns json
language sql stable security definer set search_path = auth, pg_temp
as $$
  select json_build_object(
           'id', id, 'email', email,
           'raw_user_meta_data', raw_user_meta_data,
           'raw_app_meta_data',  raw_app_meta_data)
    from auth.users
   where raw_user_meta_data->>'test_identifier' = identifier
   limit 1
$$;

-- ------------------------------------------------------------ kimliğe bürünme
-- DİKKAT — BU FONKSİYON `security invoker` OLMAK ZORUNDA VE `SET` YAN TÜMCESİ
-- TAŞIYAMAZ. Postgres, `security definer` olan ya da `SET` içeren her fonksiyona
-- girişte yeni bir GUC yuvası açıp çıkışta geri sarar; o durumda aşağıdaki
-- set_config(..., true) çağrıları fonksiyon döner dönmez silinir ve BÜTÜN RLS
-- testleri sessizce `postgres` olarak çalışıp geçer. Bu depodaki diğer her
-- fonksiyon `security definer`; buraya alışkanlıkla eklemeyin.
create or replace function tests.authenticate_as(identifier text)
returns void
language plpgsql
as $$
declare u json;
begin
  u := tests.get_supabase_user(identifier);
  if u is null or u->>'id' is null then
    raise exception 'test kullanıcısı bulunamadı: %', identifier;
  end if;
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object(
    'sub',   u->>'id',
    'role',  'authenticated',
    'aud',   'authenticated',
    'email', u->>'email',
    'user_metadata', u->'raw_user_meta_data',
    'app_metadata',  u->'raw_app_meta_data'
  )::text, true);
  -- auth.uid() önce request.jwt.claim.sub'a bakar, yoksa claims JSON'una düşer.
  -- İkisini birden kurmak sürüm farkından doğan sessiz NULL uid'i engeller.
  perform set_config('request.jwt.claim.sub', u->>'id', true);
end $$;

-- Oturumsuz (anon) rolü: grant testleri için.
create or replace function tests.authenticate_as_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', null, true);
  perform set_config('request.jwt.claim.sub', null, true);
end $$;

create or replace function tests.clear_authentication()
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', null, true);
  perform set_config('request.jwt.claim.sub', null, true);
end $$;

-- Fikstür kurmak için ayrıcalıklı oturum kullanıcısına dön.
create or replace function tests.reset_role()
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'none', true);
  perform set_config('request.jwt.claims', null, true);
  perform set_config('request.jwt.claim.sub', null, true);
end $$;

grant execute on all functions in schema tests
  to postgres, anon, authenticated, service_role;
