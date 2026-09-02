-- 0013 — Moderatör için "tüm sorular" yönetimi
-- Supabase → SQL Editor'da çalıştır.
--
-- Amaç: yanlış sınıflandırılmış / bozuk soruları SQL'e girmeden uygulamadan
-- düzeltebilmek. Tüm yetki kontrolü is_admin() ile veritabanında yapılır.

-- study_attempts hangi soruya ait olduğunu tutmuyordu; bir sorunun konusu
-- düzeltilince geçmiş ölçümler eski konuda kalıyordu. Bağ ekleniyor
-- (eski satırlar boş kalır, yeni kayıtlar bağlanır).
alter table public.study_attempts
  add column if not exists mistake_id uuid
    references public.mistakes(id) on delete set null;

create index if not exists study_attempts_mistake_idx
  on public.study_attempts (mistake_id);

-- Moderatör tüm soruların fotoğrafını görebilmeli.
create or replace function public.can_read_mistake_photo(p_name text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.is_admin() or exists (
    select 1
    from public.mistakes m
    where m.photo_path = p_name
      and (
        m.user_id = auth.uid()
        or m.is_public
        or exists (
          select 1 from public.question_sends s
          where s.mistake_id = m.id and s.receiver_id = auth.uid()
        )
      )
  );
$$;

-- ------------------------------------------------------------- listeleme
create or replace function public.admin_all_questions(
  p_limit  int default 200,
  p_offset int default 0
)
returns table (
  id             uuid,
  subject        text,
  concept        text,
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
  select m.id, m.subject, m.concept, m.exam, m.photo_path, m.options,
         m.correct_index, m.is_public, m.moderation, m.report_count,
         p.nickname, m.created_at
    from public.mistakes m
    join public.profiles p on p.id = m.user_id
   where public.is_admin()
   order by m.created_at desc
   limit greatest(1, least(p_limit, 500))
  offset greatest(0, p_offset);
$$;

grant execute on function public.admin_all_questions(int, int) to authenticated;

-- ------------------------------------------------------------- düzenleme
-- Konu düzeltilirse bağlı ölçümler de düzeltilir (harita tutarlı kalsın).
create or replace function public.admin_update_question(
  p_id            uuid,
  p_subject       text default null,
  p_concept       text default null,
  p_exam          text default null,
  p_correct_index int  default null
)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'yetkisiz';
  end if;

  update public.mistakes
     set subject       = coalesce(p_subject, subject),
         concept       = coalesce(p_concept, concept),
         exam          = coalesce(p_exam, exam),
         correct_index = coalesce(p_correct_index, correct_index)
   where id = p_id;

  update public.study_attempts
     set subject = coalesce(p_subject, subject),
         concept = coalesce(p_concept, concept),
         exam    = coalesce(p_exam, exam)
   where mistake_id = p_id;
end;
$$;

grant execute on function public.admin_update_question(uuid, text, text, text, int)
  to authenticated;

-- --------------------------------------------------- havuz durumu / silme
-- p_action: 'hide' (havuzdan çıkar) | 'restore' (geri al) | 'delete' (sil)
create or replace function public.admin_question_action(
  p_id     uuid,
  p_action text
)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'yetkisiz';
  end if;

  if p_action = 'hide' then
    update public.mistakes set moderation = 'removed' where id = p_id;
  elsif p_action = 'restore' then
    update public.mistakes set moderation = 'ok' where id = p_id;
    update public.question_reports
       set status = 'dismissed', reviewed_at = now()
     where mistake_id = p_id and status = 'pending';
  elsif p_action = 'delete' then
    delete from public.mistakes where id = p_id;
  else
    raise exception 'geçersiz işlem';
  end if;
end;
$$;

grant execute on function public.admin_question_action(uuid, text) to authenticated;
