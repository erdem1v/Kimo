-- test: supabase/tests/100_ai_quota.sql
--
-- MUTASYON: `premium_until` sütununu istemciye aç.
-- BEKLENEN: 100'ün "kullanıcı kendini premium yapamaz" iddiası kırmızı.
--
-- Kota rejiminin TAMAMI bu tek sütuna dayanıyor: yazılabilir olsaydı herkes
-- 50/8sa + 1.000/ay alırdı.
grant update (premium_until) on public.profiles to authenticated;
-- @UNDO
-- Tablo düzeyi REVOKE sütun grant'larını da siler; sonra 0077'deki tek meşru
-- sütunu geri veriyoruz (05_xp_lockdown ile aynı iki adım).
revoke insert, update on public.profiles from public, anon, authenticated;
grant update (avatar_path) on public.profiles to authenticated;
