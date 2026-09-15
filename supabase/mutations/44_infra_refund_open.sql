-- test: supabase/tests/100_ai_quota.sql
--
-- MUTASYON: tavansiz iade yolunu istemciye ac.
-- BEKLENEN: 100'un "tavansiz iade yolu authenticated'a KAPALI" ve "istemci
-- tavansiz iade yolunu CAGIRAMIYOR" iddialari kirmizi.
--
-- NEDEN BU BIR KORUMA: `refund_ai_use_infra` TAVANSIZ. Istemciye acilirsa
-- kullanici kendi butun `ai_calls` satirlarini iade eder; iade edilen satir
-- hem kayan pencereden hem AYLIK cap'ten dustugu icin sonuc "OpenAI cagrisi
-- yapildi, kota geri verildi" olur — yani sert maliyet tavani diye bir sey
-- kalmaz. Ilk yazimda tam bu delik vardi: tavan `p_capped boolean` ile
-- kapatilabiliyordu ve parametre ISTEMCIDEN geliyordu.
grant execute on function public.refund_ai_use_infra(text, bigint) to authenticated;
-- @UNDO
revoke execute on function public.refund_ai_use_infra(text, bigint)
  from public, authenticated;
grant  execute on function public.refund_ai_use_infra(text, bigint) to anon;
