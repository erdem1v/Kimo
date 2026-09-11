-- test: supabase/tests/300_ad_reward.sql
--
-- MUTASYON: ödül verme RPC'sini istemciye aç.
-- BEKLENEN: 300'ün "grant_ad_reward authenticated'a KAPALI" iddiası kırmızı.
--
-- Bu paketin en önemli tek koruması. Açık olsaydı istemci nonce'unu zaten
-- bildiği için (kendisi istedi) kendine sınırsız reklam hakkı basardı ve
-- sunucu tarafı doğrulamanın tamamı dekora dönerdi.
grant execute on function public.grant_ad_reward(uuid, text, text)
  to authenticated;
-- @UNDO
revoke execute on function public.grant_ad_reward(uuid, text, text)
  from public, authenticated;
grant execute on function public.grant_ad_reward(uuid, text, text) to anon;
