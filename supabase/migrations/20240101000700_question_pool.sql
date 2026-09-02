-- 0007 — Soru havuzu: başkalarının hatalarını çözme
-- Supabase → SQL Editor'da çalıştır.
--
-- MAHREMİYET: paylaşım OPT-IN'dir. is_public varsayılanı false, yani mevcut
-- hiçbir soru geriye dönük paylaşılmaz. Kullanıcı ekleme ekranında açıkça
-- onaylarsa sorusu havuza girer.

-- ------------------------------------------------ mistakes: paylaşım alanları
alter table public.mistakes
  add column if not exists is_public      boolean not null default false,
  add column if not exists solved_correct int not null default 0,
  add column if not exists solved_wrong   int not null default 0;

create index if not exists mistakes_public_idx
  on public.mistakes (is_public) where is_public;

-- ------------------------------------------------------- havuz denemeleri
-- Kullanıcı başına soru başına tek kayıt: hem istatistik hem "bunu zaten
-- çözdüm" filtresi için.
create table if not exists public.question_attempts (
  mistake_id uuid not null references public.mistakes(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  correct    boolean not null,
  created_at timestamptz not null default now(),
  primary key (mistake_id, user_id)
);

alter table public.question_attempts enable row level security;

drop policy if exists attempts_select_own on public.question_attempts;
create policy attempts_select_own on public.question_attempts
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists attempts_insert_own on public.question_attempts;
create policy attempts_insert_own on public.question_attempts
  for insert to authenticated with check (auth.uid() = user_id);

-- Deneme kaydedilince sorunun sayaçlarını güncelle.
create or replace function public.bump_question_counters()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.correct then
    update public.mistakes set solved_correct = solved_correct + 1
    where id = new.mistake_id;
  else
    update public.mistakes set solved_wrong = solved_wrong + 1
    where id = new.mistake_id;
  end if;
  return new;
end;
$$;

drop trigger if exists on_question_attempt on public.question_attempts;
create trigger on_question_attempt
  after insert on public.question_attempts
  for each row execute function public.bump_question_counters();

-- --------------------------------------------------- herkese açık soru görünümü
-- Yalnızca paylaşıma açılmış, fotoğrafı ve şıkları olan sorular. Sahibinin
-- yalnızca takma adı görünür (e-posta, not, hata türü paylaşılmaz).
drop view if exists public.public_questions;
create view public.public_questions
  with (security_invoker = false)
  as select
       m.id,
       m.user_id       as owner_id,
       p.nickname      as owner_nickname,
       m.subject,
       m.concept,
       m.exam,
       m.photo_path,
       m.options,
       m.correct_index,
       m.solved_correct,
       m.solved_wrong,
       m.created_at
     from public.mistakes m
     join public.profiles p on p.id = m.user_id
     where m.is_public
       and m.photo_path is not null
       and m.options is not null
       and m.correct_index is not null;

grant select on public.public_questions to authenticated;

-- Rastgele soru getir: kendi soruların ve daha önce çözdüklerin hariç.
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
  order by random()
  limit greatest(1, least(p_limit, 50));
$$;

grant execute on function public.random_public_questions(int) to authenticated;

-- ------------------------------------------------- havuz fotoğraflarına erişim
-- Paylaşıma açılmış soruların fotoğrafları diğer kullanıcılarca okunabilir.
-- (Özel sorular etkilenmez; onlar sahibinin klasör kuralıyla korunur.)
drop policy if exists "public question photos readable" on storage.objects;
create policy "public question photos readable" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'mistake-photos'
    and exists (
      select 1 from public.mistakes m
      where m.photo_path = storage.objects.name and m.is_public
    )
  );
