-- test: supabase/tests/098_function_grants.sql
--
-- MUTASYON: send_push'u tekrar çağrılabilir yap (H7'nin RPC yüzeyi).
-- BEKLENEN: 098'in "send_push authenticated'a KAPALI" iddiası kırmızı.
grant execute on function public.send_push(uuid, text, text, text) to authenticated;
-- @UNDO
revoke execute on function public.send_push(uuid, text, text, text)
  from public, anon, authenticated;
