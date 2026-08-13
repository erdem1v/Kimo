-- 0016 — Haritada konu başına "çözülebilir soru" sayısı
-- Supabase → SQL Editor'da çalıştır.
--
-- Soru havuzu haritayla birleşiyor: kullanıcı konuyu haritadan seçip çözüyor.
-- Boş konuya tıklayıp "soru yok" duvarına toslamasın diye, her konuda kaç
-- soru çözebileceğini önceden gösteriyoruz. Sayım kullanıcıya özeldir:
-- kendi soruları, daha önce çözdükleri ve bildirdikleri sayılmaz.

create or replace function public.available_question_counts()
returns table (subject text, concept text, cnt int)
language sql
stable
security definer set search_path = public
as $$
  select q.subject, q.concept, count(*)::int
    from public.public_questions q
   where q.owner_id <> auth.uid()
     and not exists (
       select 1 from public.question_attempts a
       where a.mistake_id = q.id and a.user_id = auth.uid()
     )
     and not exists (
       select 1 from public.question_reports r
       where r.mistake_id = q.id and r.reporter_id = auth.uid()
     )
   group by q.subject, q.concept;
$$;

grant execute on function public.available_question_counts() to authenticated;
