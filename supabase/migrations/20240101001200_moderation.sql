-- 0012 — Moderasyon: inceleme kuyruğu + istismara karşı koruma
-- Supabase → SQL Editor'da çalıştır.
--
-- 0011'de şikayet gelen soru doğrudan is_public=false yapılıyordu. İki sorun:
--   1) Kimse incelemiyordu: gizleme kalıcı bir hükme dönüşüyordu, geri dönüş yok.
--   2) İstismar: tek kişi "uygunsuz" diyerek düzgün bir soruyu düşürebiliyordu.
--
-- Çözüm: otomatik gizleme artık GEÇİCİ bir sigorta (moderation='hidden'),
-- hüküm değil. Karar admin incelemesiyle verilir: kaldır ('removed') ya da
-- geri al ('ok'). Haksız çıkan şikayetler bildiren kişiye yazılır; ısrarla
-- haksız bildiren birinin şikayeti artık tek başına soru gizleyemez.

-- ------------------------------------------------------------- moderasyon
alter table public.mistakes
  add column if not exists moderation text not null default 'ok'
    check (moderation in ('ok', 'hidden', 'removed'));

alter table public.profiles
  add column if not exists is_admin bool not null default false,
  add column if not exists dismissed_reports int not null default 0;

alter table public.question_reports
  add column if not exists status text not null default 'pending'
    check (status in ('pending', 'upheld', 'dismissed')),
  add column if not exists reviewed_at timestamptz;

create index if not exists question_reports_status_idx
  on public.question_reports (status, created_at);

-- 0011'de is_public ile gizlenmiş sorular varsa moderasyona taşı: sahibinin
-- paylaşım niyeti korunsun, karar moderasyon alanında dursun.
update public.mistakes
   set moderation = 'hidden', is_public = true
 where is_public = false
   and report_count > 0
   and moderation = 'ok';

-- ------------------------------------------------------- yardımcı sorgular
create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select coalesce((select p.is_admin from public.profiles p
                    where p.id = auth.uid()), false);
$$;

grant execute on function public.is_admin() to authenticated;

-- --------------------------------------------------- şikayet geldiğinde
create or replace function public.apply_question_report()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_safety_trusted int;
  v_total          int;
  v_dismissed      int;
begin
  -- Bildiren kişinin geçmişi: ısrarla haksız bildirenin sesi kısılır.
  select coalesce(p.dismissed_reports, 0) into v_dismissed
    from public.profiles p where p.id = new.reporter_id;

  -- Güvenlik şikayetleri YALNIZCA güvenilir bildirenlerden sayılır.
  select count(*) filter (
           where r.reason in ('inappropriate', 'personal_info')
             and coalesce(rp.dismissed_reports, 0) < 3
         ),
         count(*)
    into v_safety_trusted, v_total
    from public.question_reports r
    left join public.profiles rp on rp.id = r.reporter_id
   where r.mistake_id = new.mistake_id
     and r.status <> 'dismissed';

  update public.mistakes
     set report_count = v_total,
         -- GEÇİCİ gizleme; kalıcı karar admin incelemesinde verilir.
         moderation = case
                        when moderation = 'removed' then 'removed'
                        when v_safety_trusted >= 1 or v_total >= 3 then 'hidden'
                        else moderation
                      end
   where id = new.mistake_id;

  return new;
end;
$$;

-- ------------------------------------------------------ havuz görünümü
-- Havuza yalnızca sahibi paylaşmışsa VE moderasyondan geçmişse çıkar.
-- NOT: drop edilemez — random_public_questions ve random_questions_by_topic
-- bu görünümü dönüş tipi olarak kullanıyor. Kolon listesi aynı kaldığı için
-- "create or replace" ile yerinde güncelliyoruz.
create or replace view public.public_questions
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
       and m.moderation = 'ok'
       and m.photo_path is not null
       and m.options is not null
       and m.correct_index is not null;

grant select on public.public_questions to authenticated;

-- ------------------------------------------------------ admin: kuyruk
-- İncelenmeyi bekleyen şikayetler (yalnızca adminler).
create or replace function public.admin_pending_reports()
returns table (
  report_id   uuid,
  mistake_id  uuid,
  reason      text,
  note        text,
  created_at  timestamptz,
  subject     text,
  concept     text,
  photo_path  text,
  options     jsonb,
  correct_index int,
  owner_nickname text,
  report_count  int,
  moderation    text
)
language sql stable security definer set search_path = public
as $$
  select r.id, m.id, r.reason, r.note, r.created_at,
         m.subject, m.concept, m.photo_path, m.options, m.correct_index,
         p.nickname, m.report_count, m.moderation
    from public.question_reports r
    join public.mistakes m on m.id = r.mistake_id
    join public.profiles p on p.id = m.user_id
   where r.status = 'pending'
     and public.is_admin()
   order by
     -- güvenlik şikayetleri önce
     (r.reason in ('inappropriate', 'personal_info')) desc,
     r.created_at asc;
$$;

grant execute on function public.admin_pending_reports() to authenticated;

-- ------------------------------------------------------ admin: karar
-- p_action: 'remove'  → soru havuzdan kalıcı çıkar, şikayet haklı sayılır
--           'dismiss' → şikayet haksız; soru geri gelir, bildirene yazılır
create or replace function public.moderate_report(
  p_report uuid,
  p_action text
)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_mistake  uuid;
  v_reporter uuid;
begin
  if not public.is_admin() then
    raise exception 'yetkisiz';
  end if;
  if p_action not in ('remove', 'dismiss') then
    raise exception 'geçersiz işlem';
  end if;

  select mistake_id, reporter_id into v_mistake, v_reporter
    from public.question_reports where id = p_report;
  if v_mistake is null then
    raise exception 'şikayet bulunamadı';
  end if;

  if p_action = 'remove' then
    update public.question_reports
       set status = 'upheld', reviewed_at = now()
     where id = p_report;
    update public.mistakes set moderation = 'removed' where id = v_mistake;
  else
    update public.question_reports
       set status = 'dismissed', reviewed_at = now()
     where id = p_report;
    -- Haksız bildirim bildirenin siciline yazılır.
    update public.profiles
       set dismissed_reports = dismissed_reports + 1
     where id = v_reporter;
    -- Başka bekleyen/haklı şikayeti yoksa soru havuza geri döner.
    if not exists (
      select 1 from public.question_reports
       where mistake_id = v_mistake and status in ('pending', 'upheld')
    ) then
      update public.mistakes
         set moderation = 'ok'
       where id = v_mistake and moderation = 'hidden';
    end if;
  end if;
end;
$$;

grant execute on function public.moderate_report(uuid, text) to authenticated;
