-- test: supabase/tests/060_answers_xp.sql
--
-- MUTASYON: XP sütunlarını istemciye geri aç (C3'ü geri getir).
-- BEKLENEN: 060'ın "kullanıcı kendine XP yazamıyor" iddiası kırmızı.
grant update (xp, weekly_xp, streak) on public.profiles to authenticated;
-- @UNDO
-- Tablo düzeyi REVOKE, ilgili SÜTUN düzeyi grant'ları da siler; sonra
-- 0036'daki tek meşru sütunu geri veriyoruz.
revoke insert, update on public.profiles from public, anon, authenticated;
grant update (avatar_path) on public.profiles to authenticated;
