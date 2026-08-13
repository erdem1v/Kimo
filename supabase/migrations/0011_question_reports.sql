-- 0011 — Havuz sorularını şikayet etme (moderasyon)
-- Supabase → SQL Editor'da çalıştır.
--
-- Şikayetler iki sınıfa ayrılır:
--   GÜVENLİK (uygunsuz içerik, kişisel bilgi): tek şikayette soru havuzdan
--     düşer. Zarar asimetrik — yanlışlıkla gizlenen soru ucuz, sızan kişisel
--     bilgi geri alınamaz.
--   KALİTE (okunmuyor, cevap yanlış, yanlış konu...): 3 şikayette düşer.
-- Her iki durumda da soru sahibinin kaydı silinmez; yalnızca is_public=false
-- olur, yani havuzdan çıkar ama kişinin kendi hata bankasında kalır.

alter table public.mistakes
  add column if not exists report_count int not null default 0;

create table if not exists public.question_reports (
  id          uuid primary key default gen_random_uuid(),
  mistake_id  uuid not null references public.mistakes(id) on delete cascade,
  reporter_id uuid not null default auth.uid()
                references auth.users(id) on delete cascade,
  reason      text not null check (reason in (
                'unreadable',     -- soru okunmuyor
                'options_wrong',  -- şıkların yeri/metni yanlış
                'answer_wrong',   -- işaretli cevap yanlış
                'wrong_topic',    -- yanlış ders/konu
                'inappropriate',  -- uygunsuz içerik
                'personal_info',  -- kişisel bilgi
                'other'           -- başka bir sorun (note)
              )),
  note        text,
  created_at  timestamptz not null default now(),
  unique (mistake_id, reporter_id)   -- aynı kişi aynı soruyu bir kez bildirir
);

create index if not exists question_reports_mistake_idx
  on public.question_reports (mistake_id);

alter table public.question_reports enable row level security;

-- Kendi şikayetini oluşturabilir ve görebilirsin; başkalarınınkini göremezsin.
drop policy if exists reports_insert_own on public.question_reports;
create policy reports_insert_own on public.question_reports
  for insert to authenticated with check (auth.uid() = reporter_id);

drop policy if exists reports_select_own on public.question_reports;
create policy reports_select_own on public.question_reports
  for select to authenticated using (auth.uid() = reporter_id);

-- Şikayet gelince eşiklere göre soruyu havuzdan düşür.
create or replace function public.apply_question_report()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_safety int;
  v_total  int;
begin
  select count(*) filter (where reason in ('inappropriate', 'personal_info')),
         count(*)
    into v_safety, v_total
    from public.question_reports
   where mistake_id = new.mistake_id;

  update public.mistakes
     set report_count = v_total,
         is_public = case
                       when v_safety >= 1 or v_total >= 3 then false
                       else is_public
                     end
   where id = new.mistake_id;

  return new;
end;
$$;

drop trigger if exists on_question_report on public.question_reports;
create trigger on_question_report
  after insert on public.question_reports
  for each row execute function public.apply_question_report();

-- Bildirdiğin soru bir daha karşına çıkmasın (havuz ve konu testi).
create or replace function public.random_public_questions(p_limit int default 10)
returns setof public.public_questions
language sql
security definer set search_path = public
as $$
  select q.*
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
  order by random()
  limit greatest(1, least(p_limit, 50));
$$;

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
    and not exists (
      select 1 from public.question_reports r
      where r.mistake_id = q.id and r.reporter_id = auth.uid()
    )
  order by random()
  limit greatest(1, least(p_limit, 50));
$$;
