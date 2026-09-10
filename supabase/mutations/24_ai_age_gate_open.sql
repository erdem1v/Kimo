-- test: supabase/tests/130_age_gate.sql
--
-- MUTASYON: yaş kapısını her zaman açık bırak (0067 öncesine dön).
-- BEKLENEN: 130'un "doğum yılı YOKKEN analiz reddediliyor" iddiası kırmızı.
--
-- Neden bu mutasyon: kapı bir `boolean` döndürüyor ve `true` dönmesi hiçbir
-- yapıyı bozmuyor — fonksiyon var, çağrılabiliyor, edge function yanıt
-- alıyor. Tek fark fotoğrafın yaş bilinmeden OpenAI'a gitmesi; yani bu, kodda
-- hiçbir iz bırakmayan ama hukuki metinle doğrudan çelişen bir gerileme.
-- Yakalayan tek şey testin sonucu GERÇEKTEN okuması.
create or replace function public.ai_age_ok()
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select true;
$fn$;

-- @UNDO
create or replace function public.ai_age_ok()
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select public.has_birth_year(auth.uid());
$fn$;
