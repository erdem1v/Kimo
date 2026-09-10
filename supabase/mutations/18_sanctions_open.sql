-- test: supabase/tests/270_sanctions.sql
--
-- MUTASYON: yaptırım defterlerini istemciye aç.
-- BEKLENEN: 270'in "kullanıcı kendi sicilini okuyamıyor / kendi askısını
-- kaldıramıyor / ihlalini silemiyor" iddiaları kırmızı.
--
-- Neden bu mutasyon: sayacın ve askının değerinin TAMAMI kullanıcının onlara
-- dokunamamasında. Tablolar açık olsaydı üç ihlal biriktiren biri `delete from
-- photo_violations` ile sicilini temizler, `insert ... 'lift'` ile askısını
-- kaldırırdı — yaptırım altyapısı bir dekora dönerdi.
grant select, insert, update, delete on public.user_sanctions   to authenticated;
grant select, insert, update, delete on public.photo_violations to authenticated;
-- @UNDO
revoke all on public.user_sanctions   from public, anon, authenticated;
revoke all on public.photo_violations from public, anon, authenticated;
