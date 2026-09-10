-- test: supabase/tests/280_directory.sql
--
-- MUTASYON: `profiles_public` görünümünü yeniden `authenticated`'a aç
-- (0068 öncesine dön).
-- BEKLENEN: 280'in "dizin dökülemiyor" iddiaları kırmızı.
--
-- Neden bu mutasyon: 0068'in kapattığı şey bir FONKSİYON değil bir GRANT.
-- `create or replace view` grant'ları KORUYOR, yani görünümü yeniden
-- tanımlayan sonraki bir göç eski `grant select`i farkında olmadan
-- diriltebilir — ve hiçbir şey patlamaz, hiçbir hata görünmez. Dizin sessizce
-- yeniden dökülebilir hâle gelir. Bu testin ayırt ettiği tam olarak o sessiz
-- gerileme.
grant select on public.profiles_public to authenticated;

-- @UNDO
revoke select on public.profiles_public from authenticated, anon, public;
