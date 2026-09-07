-- 0050 — Fotoğraf içerik taraması: şüpheli içerik PAYLAŞIMA çıkamaz (Task 03,
-- bulgu 4.3).
--
-- SORUN: AI yalnızca "okunabilir mi, soru mu" diye bakıyordu; soru gibi
-- görünen ama üzerine uygunsuz içerik yazılmış bir sayfa filtreden geçip
-- birebir paylaşımla başka bir kullanıcıya — muhtemelen reşit olmayan birine —
-- gidebiliyordu. Moderasyon tamamen TEPKİSELDİ (şikâyet → admin).
--
-- TASARIM: tarama, KAYITLI NESNE üzerinde ve sunucuda yapılır (yeni edge
-- function `scan-photos`, OpenAI omni-moderation). analyze-question içinde
-- yapılmamasının nedeni: (a) elle giriş ve kota-bitmiş yolunda analiz hiç
-- çağrılmıyor, (b) analiz ham byte'lara bakıyor — istemci masum görsel analiz
-- ettirip depoya BAŞKA byte yükleyebilir. Karar yüklenen nesneye bağlanmalı.
--
-- DURUM MAKİNESİ (`photo_scan`): pending → clear | flagged.
--   • Yeni yüklenen her fotoğraf 'pending' başlar.
--   • 'clear' değilse PAYLAŞILAMAZ: havuz görünümü, arkadaşa gönderme
--     politikası ve fotoğraf okuma yetkisinin paylaşım dalları kapalı.
--   • SAHİP her durumda kendi fotoğrafını görür ve kaydını kullanır — yanlış
--     pozitif öğrenciyi kilitlemez (task şartı).
--   • Tarama başarısız olursa 'pending' kalır: paylaşım için kapalı (temkinli),
--     kişisel kullanım için açık.
--   • Mevcut kayıtlar 'clear' kabul edilir (zaten canlıda/paylaşımda; geriye
--     dönük tarama ayrı bir izleme işi olarak rapora not edildi).
--
-- 'moderation' EKSENİNE KARIŞMAZ: o, şikâyet sayacına ve admin kararına bağlı
-- ayrı bir durum makinesi (0012). Makine kararını oraya karıştırmak şikâyet
-- sigortasının değişmezlerini bozardı. Görünürlük = iki eksenin AND'i.

-- ------------------------------------------------------------------ kolonlar
alter table public.mistakes
  add column if not exists photo_scan text not null default 'clear'
    check (photo_scan in ('pending', 'clear', 'flagged')),
  add column if not exists photo_scan_at timestamptz;

comment on column public.mistakes.photo_scan is
  'Fotoğrafın makine taraması: pending (taranmadı — paylaşılamaz), clear, '
  'flagged (şüpheli — paylaşılamaz, admin incelemesinde). Sahibin erişimini '
  'HİÇBİR değeri kısıtlamaz.';

-- Süpürücünün kuyruğu: bekleyenler.
create index if not exists mistakes_scan_pending_idx
  on public.mistakes (created_at)
  where photo_scan = 'pending' and photo_path is not null;

-- ------------------------------------------------------------- tetikleyici
-- Yeni/değişen fotoğraf her zaman 'pending' başlar. İstemci kolona yazamaz
-- (0053 lockdown v3'te kilitli); tek yazarlar bu tetikleyici ve servis rolü.
create or replace function public.mistakes_photo_scan_reset()
returns trigger language plpgsql as $$
begin
  if new.photo_path is not null
     and (tg_op = 'INSERT' or new.photo_path is distinct from old.photo_path)
  then
    new.photo_scan := 'pending';
    new.photo_scan_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists mistakes_photo_scan_reset on public.mistakes;
create trigger mistakes_photo_scan_reset
  before insert or update of photo_path
  on public.mistakes
  for each row
  execute function public.mistakes_photo_scan_reset();

-- ------------------------------------------------------ paylaşım kapıları
-- (1) Havuz görünümü: yalnız 'clear'. Kolon listesi 0030 (hide_correct_index)
-- ile birebir aynı — correct_index BİLEREK YOK (doğru cevap yalnızca
-- submit_*_answer yanıtında döner; o karar burada aynen korunuyor).
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
       m.solved_correct,
       m.solved_wrong,
       m.created_at,
       m.source,
       m.source_year,
       m.source_session
     from public.mistakes m
     join public.profiles p on p.id = m.user_id
     where m.is_public
       and m.moderation = 'ok'
       and m.photo_scan = 'clear'
       and m.photo_path is not null
       and m.options is not null
       and m.correct_index is not null;

grant select on public.public_questions to authenticated;

-- (2) Arkadaşa gönderme: gönderilen sorunun fotoğrafı taranmış olmalı.
drop policy if exists sends_insert_friend on public.question_sends;
create policy sends_insert_friend on public.question_sends
  for insert to authenticated
  with check (
    auth.uid() = sender_id
    and not exists (
      select 1 from public.profiles p
       where p.id = auth.uid() and p.is_anonymous
    )
    and public.are_friends(sender_id, receiver_id)
    and not exists (
      select 1 from public.user_blocks b
       where (b.blocker_id = receiver_id and b.blocked_id = sender_id)
          or (b.blocker_id = sender_id   and b.blocked_id = receiver_id)
    )
    -- Taranmamış/şüpheli fotoğraf BAŞKASINA gidemez. Fotoğrafsız soru
    -- gönderilemiyor zaten (received_questions photo_path ister); yine de
    -- null'u açık bırakmıyoruz.
    and exists (
      select 1 from public.mistakes m
       where m.id = mistake_id
         and m.user_id = auth.uid()
         and m.moderation = 'ok'
         and m.photo_scan = 'clear'
    )
  );

-- (3) Fotoğraf okuma: sahiplik dalı DOKUNULMADAN kalır (yanlış pozitif
-- kilitlemez); havuz ve gönderim dalları 'clear' ister.
create or replace function public.can_read_mistake_photo(p_name text)
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select public.is_admin() or exists (
    select 1
    from public.mistakes m
    where m.photo_path = p_name
      and m.user_id::text = (storage.foldername(p_name))[1]
      and m.moderation <> 'removed'
      and (
        m.user_id = auth.uid()                       -- kendi fotoğrafın: taramadan bağımsız
        or (m.is_public       and m.photo_scan = 'clear')
        or (m.photo_scan = 'clear' and exists (
          select 1 from public.question_sends s
          where s.mistake_id = m.id and s.receiver_id = auth.uid()
        ))
      )
  );
$fn$;

-- (4) Gelen kutusu görünümü: gönderim anında 'clear' olsa da SONRADAN
-- işaretlenen içerik kutudan da düşer — reşit olmayan alıcının kutusunda
-- şüpheli içeriğin üst verisi bile durmasın. Kolon listesi 0046 ile aynı.
create or replace view public.received_questions
with (security_invoker = false) as
select
  s.id                as send_id,
  s.sender_id,
  sp.nickname         as sender_nickname,
  sp.mascot           as sender_mascot,
  s.note,
  s.created_at,
  s.solved_at,
  s.correct,
  m.id                as mistake_id,
  m.subject,
  m.concept,
  m.exam,
  m.photo_path,
  m.options,
  case when s.solved_at is not null then m.correct_index end as correct_index
from public.question_sends s
join public.mistakes m on m.id = s.mistake_id
join public.profiles sp on sp.id = s.sender_id
where s.receiver_id = auth.uid()
  and m.photo_path is not null
  and m.options is not null
  and m.correct_index is not null
  and m.moderation <> 'removed'
  and m.photo_scan = 'clear'
  and not exists (
    select 1 from public.question_reports r
     where r.mistake_id = m.id
       and r.reporter_id = auth.uid()
       and r.status = 'pending'
  )
  and not exists (
    select 1 from public.user_blocks b
     where b.blocker_id = auth.uid()
       and b.blocked_id = s.sender_id
  )
  and s.dismissed_at is null;

revoke all on public.received_questions from public, anon;
grant select on public.received_questions to authenticated;

-- ---------------------------------------------------------- onay defteri
-- Yapay zekâya aktarım bildirimi de deftere yazılır ('ai_upload'): kullanıcı
-- fotoğrafın OpenAI'ya gideceğini İLK analizden önce onaylar (istemci akışı).
alter table public.user_consents
  drop constraint if exists user_consents_kind_check;
alter table public.user_consents
  add constraint user_consents_kind_check
  check (kind in ('guardian', 'share', 'ai_upload'));

create or replace function public.record_consent(
  p_kind    text,
  p_granted boolean
)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid  uuid := auth.uid();
  v_last boolean;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_kind not in ('guardian', 'share', 'ai_upload') then
    raise exception 'geçersiz onay türü' using errcode = '22023';
  end if;
  if p_granted is null then
    raise exception 'onay değeri boş olamaz' using errcode = '22023';
  end if;

  select c.granted into v_last
    from public.user_consents c
   where c.user_id = v_uid and c.kind = p_kind
   order by c.recorded_at desc
   limit 1;

  if v_last is not distinct from p_granted then
    return;
  end if;

  insert into public.user_consents (user_id, kind, granted, source)
  values (v_uid, p_kind, p_granted, 'settings');
end
$fn$;

revoke execute on function public.record_consent(text, boolean) from public, anon;
grant  execute on function public.record_consent(text, boolean) to authenticated;

-- ------------------------------------------------------- tarama oranı
-- scan-photos'un kullanıcı hızlı yolu için oran sınırı. `bump_rate_limit`
-- BİLEREK kapalı (recheck3 gerekçesi: kullanıcı kendi sayacını
-- manipüle edebilirdi); bu sarmalayıcı kova adını ve sınırı sabitliyor —
-- çağıran yalnızca "bugün hakkım var mı" sorabiliyor.
create or replace function public.consume_scan_use()
returns boolean
language sql security definer set search_path = public
as $fn$
  select public.bump_rate_limit('scan', 20, public.istanbul_day()::text);
$fn$;

revoke execute on function public.consume_scan_use() from public, anon;
grant  execute on function public.consume_scan_use() to authenticated;

-- ------------------------------------------------------ admin incelemesi
-- Şüpheli fotoğraflar admin ekranında listelenir; karar iki yönlü:
--   'clear'  → yanlış pozitifti, paylaşıma açılır
--   'remove' → moderation='removed' — mevcut purge kuyruğuna (0031) akar,
--              depolama değişmezleri aynen işler.
create or replace function public.admin_flagged_photos()
returns table (mistake_id uuid, owner_id uuid, photo_path text,
               subject text, concept text, flagged_at timestamptz)
language sql stable security definer set search_path = public
as $fn$
  select m.id, m.user_id, m.photo_path, m.subject, m.concept, m.photo_scan_at
    from public.mistakes m
   where public.is_admin()
     and m.photo_scan = 'flagged'
     and m.moderation <> 'removed'
   order by m.photo_scan_at nulls last;
$fn$;

revoke execute on function public.admin_flagged_photos() from public, anon;
grant  execute on function public.admin_flagged_photos() to authenticated;

create or replace function public.admin_review_photo_scan(
  p_id     uuid,
  p_action text
)
returns void
language plpgsql security definer set search_path = public
as $fn$
begin
  if not public.is_admin() then
    raise exception 'yetkisiz' using errcode = '42501';
  end if;
  if p_action = 'clear' then
    update public.mistakes
       set photo_scan = 'clear', photo_scan_at = now()
     where id = p_id;
  elsif p_action = 'remove' then
    update public.mistakes
       set moderation = 'removed'
     where id = p_id;
  else
    raise exception 'geçersiz eylem' using errcode = '22023';
  end if;
end
$fn$;

revoke execute on function public.admin_review_photo_scan(uuid, text)
  from public, anon;
grant  execute on function public.admin_review_photo_scan(uuid, text)
  to authenticated;
