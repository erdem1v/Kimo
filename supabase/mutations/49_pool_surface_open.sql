-- test: supabase/tests/060_answers_xp.sql
--
-- MUTASYON: havuz paylasim RPC'sini istemciye geri ac.
-- BEKLENEN: 060'in "set_question_sharing istemciye KAPALI" ve calisma zamani
-- 42501 iddialari kirmizi.
--
-- NEDEN BU BIR KORUMA: havuz arayuzden cikti (Task 02, lib/_archive) ama
-- sunucu acik kalmisti. `set_question_sharing`in `lib/` icinde TEK bir
-- cagirani yok; acik olmasi kullanicinin kendi soru FOTOGRAFINI takma adiyla
-- tum oturumlu kullanicilara acabilmesi demekti — ustelik HICBIR onay defteri
-- kaydi olusmadan, cunku `setShareConsent` istemcide hic cagrilmiyor.
-- Gizlilik Politikasi ise havuzu "su an kullanimda degil" diye anlatiyor.
grant execute on function public.set_question_sharing(uuid, boolean) to authenticated;
-- @UNDO
revoke execute on function public.set_question_sharing(uuid, boolean)
  from public, anon, authenticated;
