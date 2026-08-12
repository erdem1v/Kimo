-- 0010 — Konu bazlı ilerleme (müfredat haritası)
-- Supabase → SQL Editor'da çalıştır.
--
-- Harita "ne kadar biliyorsun"u değil "ne kadarını ölçtük"ü gösterir. Ölçüm
-- için her çözülen sorunun konusu kaydedilmeli: tekrarlar, havuz ve arkadaştan
-- gelen sorular. Konu bilgisi denormalize tutulur (soru silinse de ilerleme
-- kaybolmasın).

create table if not exists public.study_attempts (
  id         bigserial primary key,
  user_id    uuid not null default auth.uid()
               references auth.users(id) on delete cascade,
  subject    text not null,
  concept    text not null,
  exam       text,
  correct    boolean not null,
  source     text not null default 'review',   -- 'review' | 'pool' | 'sent'
  created_at timestamptz not null default now()
);

create index if not exists study_attempts_user_topic_idx
  on public.study_attempts (user_id, subject, concept);

alter table public.study_attempts enable row level security;

drop policy if exists study_attempts_select_own on public.study_attempts;
create policy study_attempts_select_own on public.study_attempts
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists study_attempts_insert_own on public.study_attempts;
create policy study_attempts_insert_own on public.study_attempts
  for insert to authenticated with check (auth.uid() = user_id);

-- Konu bazlı özet. security_invoker = true: study_attempts'in RLS'i uygulanır,
-- yani herkes yalnızca kendi ilerlemesini görür.
drop view if exists public.my_topic_progress;
create view public.my_topic_progress
  with (security_invoker = true)
  as select
       user_id,
       subject,
       concept,
       count(*)::int                            as attempts,
       count(*) filter (where correct)::int     as correct,
       max(created_at)                          as last_at
     from public.study_attempts
     group by user_id, subject, concept;

grant select on public.my_topic_progress to authenticated;

-- Belirli bir konudan rastgele havuz soruları (haritadan "bu konuyu test et").
create or replace function public.random_questions_by_topic(
  p_subject text,
  p_concept text default null,
  p_limit   int  default 10
)
returns setof public.public_questions
language sql
security definer set search_path = public
as $$
  select q.*
  from public.public_questions q
  where q.owner_id <> auth.uid()
    and q.subject = p_subject
    and (p_concept is null or q.concept = p_concept)
    and not exists (
      select 1 from public.question_attempts a
      where a.mistake_id = q.id and a.user_id = auth.uid()
    )
  order by random()
  limit greatest(1, least(p_limit, 50));
$$;

grant execute on function public.random_questions_by_topic(text, text, int)
  to authenticated;
