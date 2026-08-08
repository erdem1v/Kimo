-- 0008 — Arkadaşa soru gönderme
-- Supabase → SQL Editor'da çalıştır.
--
-- Soru YALNIZCA arkadaşa gönderilebilir (RLS'te zorunlu). Gönderilen soru
-- havuzdan da olabilir, kişinin kendi hatasından da. Kendi (özel) sorunu
-- gönderirsen fotoğrafı yalnızca gönderdiğin kişi görebilir.

-- Arkadaşlık kontrolü (RLS içinde kullanılacak).
create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a))
  );
$$;

grant execute on function public.are_friends(uuid, uuid) to authenticated;

create table if not exists public.question_sends (
  id          uuid primary key default gen_random_uuid(),
  sender_id   uuid not null references auth.users(id) on delete cascade,
  receiver_id uuid not null references auth.users(id) on delete cascade,
  mistake_id  uuid not null references public.mistakes(id) on delete cascade,
  note        text,
  created_at  timestamptz not null default now(),
  solved_at   timestamptz,
  correct     boolean,
  unique (sender_id, receiver_id, mistake_id),
  constraint sends_no_self check (sender_id <> receiver_id)
);

create index if not exists question_sends_receiver_idx
  on public.question_sends (receiver_id, solved_at);

alter table public.question_sends enable row level security;

-- Taraflardan biriysen görürsün.
drop policy if exists sends_select_own on public.question_sends;
create policy sends_select_own on public.question_sends
  for select to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- Gönderme: yalnızca kendi adına VE yalnızca arkadaşına.
drop policy if exists sends_insert_friend on public.question_sends;
create policy sends_insert_friend on public.question_sends
  for insert to authenticated
  with check (
    auth.uid() = sender_id
    and public.are_friends(sender_id, receiver_id)
  );

-- Çözüldü işaretini yalnızca alan taraf yazabilir.
drop policy if exists sends_update_receiver on public.question_sends;
create policy sends_update_receiver on public.question_sends
  for update to authenticated
  using (auth.uid() = receiver_id)
  with check (auth.uid() = receiver_id);

-- Her iki taraf da silebilir (geri çekme / listeden kaldırma).
drop policy if exists sends_delete_own on public.question_sends;
create policy sends_delete_own on public.question_sends
  for delete to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- ------------------------------------------------ bana gelen sorular görünümü
-- security_invoker = false: mistakes tablosunun sahibe özel RLS'ini aşar ama
-- yalnızca BANA gönderilmiş satırları gösterir (aşağıdaki auth.uid() filtresi).
drop view if exists public.received_questions;
create view public.received_questions
  with (security_invoker = false)
  as select
       s.id          as send_id,
       s.sender_id,
       p.nickname    as sender_nickname,
       p.mascot      as sender_mascot,
       s.note,
       s.created_at,
       s.solved_at,
       s.correct,
       m.id          as mistake_id,
       m.subject,
       m.concept,
       m.exam,
       m.photo_path,
       m.options,
       m.correct_index
     from public.question_sends s
     join public.mistakes m on m.id = s.mistake_id
     join public.profiles p on p.id = s.sender_id
     where s.receiver_id = auth.uid()
       and m.photo_path is not null
       and m.options is not null
       and m.correct_index is not null;

grant select on public.received_questions to authenticated;

-- --------------------------------------- gönderilen soruların fotoğraflarına erişim
-- Sana gönderilmiş bir sorunun fotoğrafını okuyabilirsin (soru özel olsa bile).
drop policy if exists "sent question photos readable" on storage.objects;
create policy "sent question photos readable" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'mistake-photos'
    and exists (
      select 1
      from public.question_sends s
      join public.mistakes m on m.id = s.mistake_id
      where m.photo_path = storage.objects.name
        and s.receiver_id = auth.uid()
    )
  );
