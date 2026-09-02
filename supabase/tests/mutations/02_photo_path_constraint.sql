-- test: supabase/tests/030_photo_ownership.sql
--
-- MUTASYON: gölge satırı imkânsız kılan CHECK kısıtını düşür.
-- BEKLENEN: 030'un "başkasının klasörünü gösteren satır EKLENEMEZ" iddiası kırmızı.
alter table public.mistakes drop constraint if exists mistakes_photo_path_owned;
-- @UNDO
alter table public.mistakes drop constraint if exists mistakes_photo_path_owned;
alter table public.mistakes
  add constraint mistakes_photo_path_owned
  check (photo_path is null or photo_path like user_id::text || '/%');
