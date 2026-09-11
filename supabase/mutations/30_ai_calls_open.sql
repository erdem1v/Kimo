-- test: supabase/tests/100_ai_quota.sql
--
-- MUTASYON: çağrı defterini istemciye aç.
-- BEKLENEN: 100'ün "deftere yazılamıyor / silinemiyor" iddiaları kırmızı.
--
-- NEDEN ÖNEMLİ: bugüne kadar `rate_limits`i bozan HİÇBİR mutasyon yoktu, yani
-- eski 100'ün ayrıcalık iddiaları ayırt edilmiş değildi. Defter o kovanın
-- yerini aldığı için bu dosya onun fiilî karşılığı.
grant select, insert, delete on public.ai_calls to authenticated;
-- @UNDO
revoke all on public.ai_calls from public, anon, authenticated;
