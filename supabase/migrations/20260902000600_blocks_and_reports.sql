-- 0044 — Engelleme ve gelen soru şikâyeti
--
-- NEDEN: onaylanan tasarımın gelen kutusu ekranı (3n) App Store için zorunlu
-- üç kontrolü açıkça istiyor — **şikâyet, engelleme, silme** — ve her gelen
-- sorunun üstünde tek dokunuş uzakta olmalarını şart koşuyor.
--
-- Bugün yalnızca "sil" var: `question_sends` üzerinde her iki tarafın
-- silebildiği bir DELETE politikası. Engelleme hiç yok; şikâyet ise yalnızca
-- HAVUZ sorusu için vardı (`question_reports` + `apply_question_report`).
-- Havuz kalktı, birebir gönderim kaldı — şikâyet o yola taşınıyor.
--
-- ŞİKÂYET SÜRESİ: arayüzde "24 saat içinde incelenir" YAZMIYOR. Ekipten biri
-- kuyruğa bakıyor ama garantili bir süre taahhüt edilmiyor (task kararı).
-- Burada da bir SLA sütunu yok; yalnızca "incelenene kadar gizli" durumu var.

-- --------------------------------------------------------------- engelleme
create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_no_self check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocked_idx
  on public.user_blocks (blocked_id);

alter table public.user_blocks enable row level security;

-- Kendi engel listeni görürsün. Engellenen, engellendiğini BURADAN öğrenemez:
-- `blocked_id = auth.uid()` satırları okunamıyor. Engellendiğini bilmemesi
-- taciz senaryosunda kasıtlı — bildirim de gitmiyor.
drop policy if exists blocks_select_own on public.user_blocks;
create policy blocks_select_own on public.user_blocks
  for select to authenticated using (auth.uid() = blocker_id);

drop policy if exists blocks_insert_own on public.user_blocks;
create policy blocks_insert_own on public.user_blocks
  for insert to authenticated with check (auth.uid() = blocker_id);

drop policy if exists blocks_delete_own on public.user_blocks;
create policy blocks_delete_own on public.user_blocks
  for delete to authenticated using (auth.uid() = blocker_id);

comment on table public.user_blocks is
  'Engellenen kullanıcılar. Engellenen kişi soru gönderemez ve arkadaş isteği '
  'atamaz. Engellendiğini öğrenemez: bildirim yok, satır ona kapalı.';

-- ---------------------------------------------------- gönderimin engellenmesi
-- Mevcut politika yalnızca arkadaşlığı arıyordu. Engel, arkadaşlıktan SONRA
-- gelen bir karar: arkadaşlığı silmeden de gönderim durdurulabilmeli.
drop policy if exists sends_insert_friend on public.question_sends;
create policy sends_insert_friend on public.question_sends
  for insert to authenticated
  with check (
    auth.uid() = sender_id
    and public.are_friends(sender_id, receiver_id)
    and not exists (
      select 1 from public.user_blocks b
       where (b.blocker_id = receiver_id and b.blocked_id = sender_id)
          or (b.blocker_id = sender_id   and b.blocked_id = receiver_id)
    )
  );

-- Arkadaş isteği de engellenmiş kişiden gelemez. 0043'teki onay koşulu
-- korunuyor, üstüne engel kontrolü ekleniyor.
drop policy if exists friendships_insert_own on public.friendships;
create policy friendships_insert_own on public.friendships
  for insert to authenticated
  with check (
    auth.uid() = requester_id
    and public.can_add_friends(auth.uid())
    and not exists (
      select 1 from public.user_blocks b
       where (b.blocker_id = addressee_id and b.blocked_id = requester_id)
          or (b.blocker_id = requester_id and b.blocked_id = addressee_id)
    )
  );

-- ------------------------------------------------------------- şikâyet nedenleri
-- Tasarımdaki beş neden: uygunsuz içerik · spam · taciz/zorbalık · TELİF ·
-- diğer. `copyright` yeni; havuz dönemindeki kalite nedenleri
-- (unreadable/options_wrong/answer_wrong/wrong_topic) CHECK'te KALIYOR —
-- eski satırlar var ve onları geçersiz kılmak veriyi bozardı — ama arayüzde
-- gösterilmiyorlar.
do $mig$
declare v_name text;
begin
  select con.conname into v_name
    from pg_constraint con
    join pg_class c on c.oid = con.conrelid
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'question_reports'
     and con.contype = 'c'
     and pg_get_constraintdef(con.oid) ilike '%reason%'
   limit 1;
  if v_name is not null then
    execute format('alter table public.question_reports drop constraint %I', v_name);
  end if;
end
$mig$;

alter table public.question_reports
  add constraint question_reports_reason_check
  check (reason in (
    -- Havuz döneminden kalan kalite sebepleri: arayüzde GÖSTERİLMİYOR ama
    -- eski satırlar bu değerleri taşıyor ve onları geçersiz kılmak veriyi
    -- bozardı.
    'unreadable', 'options_wrong', 'answer_wrong', 'wrong_topic',
    -- Tasarımın (3n) beş sebebi. Her birinin KENDİ değeri var: ikisini aynı
    -- değere eşlemek moderasyon ekranında "hangi sebep" sorusunu
    -- cevaplanamaz hâle getirirdi.
    'inappropriate', 'spam', 'harassment', 'copyright', 'other',
    -- Eskiden beri var, hâlâ geçerli.
    'personal_info'
  ));

-- --------------------------------------------------- gelen soruyu şikâyet et
-- Tek çağrıda: şikâyeti yaz, istenirse göndereni engelle.
--
-- İki ayrı istemci çağrısı olsaydı ikincisi düşerse kullanıcı "engelledim"
-- sanıp engellememiş olurdu.
create or replace function public.report_received_question(
  p_send   uuid,
  p_reason text,
  p_note   text default null,
  p_block  boolean default false
)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  s     public.question_sends%rowtype;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  select * into s from public.question_sends where id = p_send;
  if not found or s.receiver_id <> v_uid then
    raise exception 'bu gönderim sana ait değil' using errcode = '42501';
  end if;

  -- Şikâyet aynı soru için bir kez (unique(mistake_id, reporter_id)).
  insert into public.question_reports (mistake_id, reporter_id, reason, note)
  values (s.mistake_id, v_uid, p_reason,
          nullif(btrim(coalesce(p_note, '')), ''))
  on conflict do nothing;

  if coalesce(p_block, false) then
    insert into public.user_blocks (blocker_id, blocked_id)
    values (v_uid, s.sender_id)
    on conflict do nothing;
  end if;
end
$fn$;

revoke execute on function public.report_received_question(uuid, text, text, boolean)
  from public, anon;
grant  execute on function public.report_received_question(uuid, text, text, boolean)
  to authenticated;

-- -------------------------------------------------- engelle / engeli kaldır
-- Politika zaten kendi satırına yazmaya izin veriyor; RPC'nin işi kendini
-- engellemeyi ve var olmayan kullanıcıyı reddetmek, ve arayüze tek bir
-- anlaşılır hata yüzeyi vermek.
create or replace function public.block_user(p_user uuid)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_user is null or p_user = v_uid then
    raise exception 'Geçersiz kullanıcı' using errcode = '22023';
  end if;
  insert into public.user_blocks (blocker_id, blocked_id)
  values (v_uid, p_user)
  on conflict do nothing;
end
$fn$;

create or replace function public.unblock_user(p_user uuid)
returns void
language plpgsql security definer set search_path = public
as $fn$
begin
  delete from public.user_blocks
   where blocker_id = auth.uid() and blocked_id = p_user;
end
$fn$;

revoke execute on function public.block_user(uuid) from public, anon;
grant  execute on function public.block_user(uuid) to authenticated;
revoke execute on function public.unblock_user(uuid) from public, anon;
grant  execute on function public.unblock_user(uuid) to authenticated;

-- ------------------------------------------------------ gelen kutusu görünümü
-- İKİ YENİ SÜZGEÇ:
--   • Şikâyet ettiğin içerik SENDEN gizlenir ("incelenene kadar bu içerik
--     senden gizlenir" — tasarımdaki söz).
--   • Engellediğin kişinin daha önce gönderdikleri de gizlenir; engelin
--     yalnızca geleceğe bakması, taciz senaryosunda yetersiz kalırdı.
--
-- `correct_index` kuralı DEĞİŞMEDİ (0035): yalnızca çözülmüş gönderimlerde
-- dönüyor.
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
  -- 0035'ten devralınan çözülebilirlik koşulları — DEĞİŞMEDİ.
  and m.photo_path is not null
  and m.options is not null
  and m.correct_index is not null
  -- YENİ: moderasyondan kaldırılan içerik gelen kutusunda da görünmesin.
  -- Depolama tarafı bunu zaten engelliyordu (fotoğraf imzalanamıyor) ama
  -- satır listede duruyor ve boş bir kart olarak görünüyordu.
  and m.moderation <> 'removed'
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
  );

revoke all on public.received_questions from public, anon;
grant select on public.received_questions to authenticated;

comment on view public.received_questions is
  'Bana gelen sorular. Şikâyet ettiklerim ve engellediklerimden gelenler '
  'gizlenir; kaldırılmış içerik hiç görünmez.';
