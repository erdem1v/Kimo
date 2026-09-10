-- test: supabase/tests/250_signup_throttle.sql
--
-- MUTASYON: IP sayacını ve kancayı istemciye aç.
-- BEKLENEN: 250'nin "sayaç authenticated tarafından okunamıyor/yazılamıyor" ve
-- "kanca authenticated'a KAPALI" iddiaları kırmızı.
--
-- Neden bu mutasyon: sayaç açık olsaydı bir kullanıcı kendi IP'sinin satırını
-- silip sınırı sıfırlayabilir, ya da başka bir hash'e sahte satır yazıp o ağdaki
-- HERKESİN kaydını engelleyebilirdi. Kanca açık olsaydı aynı şey tek RPC ile
-- yapılabilirdi — kancanın kendisi sayacı artırıyor.
grant select, insert, update, delete on public.signup_throttle to authenticated;
grant execute on function public.hook_before_user_created(jsonb) to authenticated;
-- @UNDO
revoke all on public.signup_throttle from public, anon, authenticated;
revoke execute on function public.hook_before_user_created(jsonb)
  from public, anon, authenticated;
