-- test: supabase/tests/260_ai_cache.sql
--
-- MUTASYON: önbellek tablosunu istemciye aç.
-- BEKLENEN: 260'ın "önbellek authenticated tarafından doğrudan OKUNAMIYOR /
-- yazılamıyor" iddiaları kırmızı.
--
-- Neden bu mutasyon: tablo açık olsaydı TTL kararı fonksiyonda kalmazdı —
-- istemci bayat bir satırı da okuyabilir, ya da kendi uydurduğu bir sonucu
-- yazıp analizi hiç çalıştırmadan "şıklar bunlar" diyebilirdi.
grant select, insert, update on public.ai_result_cache to authenticated;
-- @UNDO
revoke all on public.ai_result_cache from public, anon, authenticated;
