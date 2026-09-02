-- 0014 — Birden çok konuya değen sorular
-- Supabase → SQL Editor'da çalıştır.
--
-- Bazı sorular tek konuya sığmıyor (ör. hem mitoz hem mayoz soran bir soru).
-- Çözüm: ANA KONU + EK KONULAR. Soru ana konusunda gruplanır (havuz ve harita
-- düzeni bozulmaz), ama çözüldüğünde ölçüm hem ana hem ek konulara yazılır —
-- yani haritada ikisi birden dolar.

alter table public.mistakes
  add column if not exists extra_concepts text[];

-- Moderatör düzenlemesinde ek konular da güncellenebilsin.
create or replace function public.admin_update_question(
  p_id             uuid,
  p_subject        text default null,
  p_concept        text default null,
  p_exam           text default null,
  p_correct_index  int  default null,
  p_extra_concepts text[] default null
)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'yetkisiz';
  end if;

  update public.mistakes
     set subject        = coalesce(p_subject, subject),
         concept        = coalesce(p_concept, concept),
         exam           = coalesce(p_exam, exam),
         correct_index  = coalesce(p_correct_index, correct_index),
         extra_concepts = coalesce(p_extra_concepts, extra_concepts)
   where id = p_id;

  -- Konu düzeltilirse bağlı ölçümler de düzelsin (yalnızca ana konu satırları;
  -- ek konu satırları kendi konularında kalır).
  update public.study_attempts
     set subject = coalesce(p_subject, subject),
         exam    = coalesce(p_exam, exam)
   where mistake_id = p_id;

  update public.study_attempts
     set concept = coalesce(p_concept, concept)
   where mistake_id = p_id
     and concept = (select concept from public.mistakes where id = p_id);
end;
$$;

grant execute on function
  public.admin_update_question(uuid, text, text, text, int, text[])
  to authenticated;

-- Yönetim listesinde ek konular da görünsün.
drop function if exists public.admin_all_questions(int, int);
create or replace function public.admin_all_questions(
  p_limit  int default 200,
  p_offset int default 0
)
returns table (
  id             uuid,
  subject        text,
  concept        text,
  extra_concepts text[],
  exam           text,
  photo_path     text,
  options        jsonb,
  correct_index  int,
  is_public      bool,
  moderation     text,
  report_count   int,
  owner_nickname text,
  created_at     timestamptz
)
language sql stable security definer set search_path = public
as $$
  select m.id, m.subject, m.concept, m.extra_concepts, m.exam, m.photo_path,
         m.options, m.correct_index, m.is_public, m.moderation, m.report_count,
         p.nickname, m.created_at
    from public.mistakes m
    join public.profiles p on p.id = m.user_id
   where public.is_admin()
   order by m.created_at desc
   limit greatest(1, least(p_limit, 500))
  offset greatest(0, p_offset);
$$;

grant execute on function public.admin_all_questions(int, int) to authenticated;
