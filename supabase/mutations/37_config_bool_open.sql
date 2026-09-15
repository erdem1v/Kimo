-- test: supabase/tests/310_feature_flags.sql
--
-- MUTASYON: `config_bool`'u istemciye aç.
-- BEKLENEN: 310'un "config_bool authenticated'a KAPALI" ve çalışma zamanı
-- 42501 iddiaları kırmızı.
--
-- NEDEN BU BİR KORUMA: `config_bool(p_key, p_default)` ANAHTAR ADINI
-- çağırandan alıyor. İstemciye açıksa istemci `app_config`'teki herhangi bir
-- anahtarı yoklayabilir — ve orada `push_service_key` duruyor. Bayrakların
-- istemciye ulaşma yolu bilerek `feature_flags()` + görünüm; genel bir
-- yapılandırma okuyucusu değil.
grant execute on function public.config_bool(text, boolean) to authenticated;
-- @UNDO
revoke execute on function public.config_bool(text, boolean)
  from public, anon, authenticated;
