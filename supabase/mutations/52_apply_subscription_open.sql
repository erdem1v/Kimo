-- test: supabase/tests/340_subscriptions.sql
--
-- MUTASYON: `apply_subscription`i istemciye ac.
-- BEKLENEN: 340'in "apply_subscription istemciye KAPALI" iddiasi kirmizi.
--
-- NEDEN BU BIR KORUMA: bu fonksiyon PARA ile katman arasindaki tek bag.
-- `authenticated`a acilsaydi kullanici PostgREST uzerinden kendine bedava
-- abonelik yazardi — sir de govdede parametre oldugu icin yalnizca sirri
-- bilmek yeterdi ve sir, edge fonksiyonun ortaminda duruyor... AMA istemci
-- onu hic gormuyor. Yetkinin kendisi ikinci savunma: sir sizsa bile RPC
-- `authenticated`a kapali kalmali (`grant_ad_reward`in ayni iki katmani).
grant execute on function public.apply_subscription(
  text, text, text, text, timestamptz, boolean, text, uuid, jsonb) to authenticated;
-- @UNDO
revoke execute on function public.apply_subscription(
  text, text, text, text, timestamptz, boolean, text, uuid, jsonb)
  from public, authenticated;
grant execute on function public.apply_subscription(
  text, text, text, text, timestamptz, boolean, text, uuid, jsonb) to anon;
