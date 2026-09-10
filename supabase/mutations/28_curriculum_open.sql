-- test: supabase/tests/290_curriculum.sql
--
-- MUTASYON: konu ağacı tablolarını `authenticated`'a aç.
-- BEKLENEN: 290'ın "tablolar kapalı" iddiaları kırmızı.
--
-- Neden bu mutasyon: kapatan şey bir FONKSİYON değil bir GRANT. Ağacı
-- doğrudan okunabilir yapmak hiçbir şeyi patlatmaz — uygulama çalışmaya
-- devam eder, hiçbir hata görünmez. Tek fark sürüm pazarlığının ve
-- gruplamanın atlanabilir hâle gelmesi ve tek kapı ilkesinin sessizce
-- kaybolması. Yeni bir tablo ekleyen sonraki bir göç, `revoke all` yazmayı
-- unutursa tam olarak bu duruma düşer.
grant select on public.curriculum_topics  to authenticated;
grant select on public.curriculum_aliases to authenticated;
grant select on public.curriculum_meta    to authenticated;

-- @UNDO
revoke all on public.curriculum_topics  from public, anon, authenticated;
revoke all on public.curriculum_aliases from public, anon, authenticated;
revoke all on public.curriculum_meta    from public, anon, authenticated;
