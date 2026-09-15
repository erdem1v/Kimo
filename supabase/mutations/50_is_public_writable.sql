-- test: supabase/tests/020_mistakes_column_lockdown.sql
--
-- MUTASYON: `mistakes.is_public`i istemciye yazilabilir yap.
-- BEKLENEN: 020'nin "is_public YAZILAMIYOR" ve calisma zamani 42501 iddialari
-- kirmizi.
--
-- NEDEN BU BIR KORUMA: `public_questions` gorunumu `is_public and
-- moderation='ok' and photo_scan='clear'` kosullariyla TUM oturumlu
-- kullanicilara acik ve `moderation` varsayilani `'ok'`;
-- `can_read_mistake_photo` da `or m.is_public` dalini tasiyor. Yani tek bir
-- PostgREST INSERT'i kullanicinin kendi soru FOTOGRAFINI takma adiyla
-- yayinlamaya yetiyordu. Ikinci zarar `submit_pool_answer` ile birlikte
-- geliyordu: iki hesapla (biri paylasir, digeri cozer) 10 XP + seri
-- uretilebiliyordu — K.K. §6'nin "oyunlastirma mekanizmalarini hile ile
-- manipule etmek" yasagi veri katmaninda ZORLANMIYORDU.
grant insert (is_public) on public.mistakes to authenticated;
-- @UNDO
revoke insert, update on public.mistakes from public, anon, authenticated;
grant insert (subject, concept, mistake_type, note, photo_path, options,
              correct_index, exam, extra_concepts) on public.mistakes to authenticated;
grant update (subject, concept, mistake_type, note, options, correct_index,
              exam, extra_concepts, step, lapses, is_leech, mastered,
              next_review_date, next_review_at, last_reviewed_at)
  on public.mistakes to authenticated;
