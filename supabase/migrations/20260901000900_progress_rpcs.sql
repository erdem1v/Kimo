-- 0034 — Sunucu otoriteli cevaplama ve XP (E1)
--
-- SORUN (C3 + P1): xp / weekly_xp / streak / week_start / last_activity_date
-- doğrudan istemciden yazılıyordu (social_repository.dart:55). Tek bir
--     PATCH /rest/v1/profiles {"xp": 999999, "weekly_xp": 999999}
-- lig tablosunu ve skor tablosunu tamamen sahteliyordu — üstelik
-- sync_league_member_xp trigger'ı weekly_xp'yi league_members'a yansıttığı için
-- grup sıralaması da bozuluyordu. Ayrıca study_attempts.correct ve
-- question_attempts.correct istemci beyanıydı.
--
-- ÇÖZÜM: cevaplama ve puanlama sunucuya taşınıyor. Bu göç RPC'leri EKLİYOR;
-- sütunlar bir sonraki göçte kilitleniyor (istemci geçişi arada yapılıyor).
--
-- BEŞ KURAL — her biri gerçek bir tuzağı kapatıyor:
--   1. Hiçbir RPC user_id parametresi almaz. SECURITY DEFINER fonksiyon postgres
--      olarak çalışır ve profiles'ın RLS'ini tamamen atlar; user_id parametresi
--      tam bir kimliğe bürünme primitifi olurdu. Kimlik daima auth.uid().
--   2. profiles güncellemesi TEK bir UPDATE ifadesidir. İkiye bölünürse
--      sync_league_member_xp ve on_friend_milestone AFTER trigger'ları iki kez
--      çalışır ve ilki league_members.xp'ye geçici bir 0 yazar.
--   3. Satır `for update` ile kilitlenir; yoksa paralel çağrılar aynı günlük
--      sayacı okur ve her biri tam hakkı alır.
--   4. Her yeni fonksiyondan EXECUTE public/anon'dan geri alınır (Postgres
--      varsayılanı PUBLIC'tir).
--   5. week_start doğru yazılır; sync_league_member_xp `c.week_start = <bu
--      hafta>` arıyor, profil haftası kaymışsa sessizce sıfır satır eşler.

-- ------------------------------------------------------------ günlük sayaç
-- Kendi kendine raporlanan tekrar akışı için üst sınır. XP artık türetilmiş bir
-- değer; sahtelemek tek bir UPDATE yerine binlerce RPC çağrısı gerektiriyor ve
-- bu sayaç onu da sınırlıyor.
alter table public.profiles
  add column if not exists xp_today        int  not null default 0,
  add column if not exists xp_today_date   date,
  add column if not exists daily_goal_date date;

comment on column public.profiles.xp_today is
  'Bugün kazanılan XP (Europe/Istanbul günü). Kendi kendine raporlanan tekrar '
  'akışında günlük tavanı uygulamak için.';
comment on column public.profiles.daily_goal_date is
  'Günlük hedef bonusunun en son alındığı gün; bonusun günde bir kez '
  'verilmesini sunucu tarafında garanti eder.';

-- ------------------------------------------------------- yinelenme koruması
-- Çevrimdışı kuyruk (lib/data/submission_queue.dart) EN AZ BİR KEZ gönderim
-- yapıyor: yanıt kaybolursa aynı gönderim tekrar denenir. Üç akış zaten
-- kendiliğinden idempotent —
--   • submit_pool_answer  → question_attempts birincil anahtarı
--   • submit_sent_answer  → solved_at is null koşulu
--   • claim_daily_goal    → daily_goal_date
-- ama submit_review değil: tekrar gönderilirse ölçüm ikilenir ve XP iki kez
-- verilir. Bu tablo o akış için tek seferlik anahtarı tutuyor.
create table if not exists public.submission_tokens (
  user_id    uuid not null default auth.uid()
               references auth.users(id) on delete cascade,
  token      uuid not null,
  created_at timestamptz not null default now(),
  primary key (user_id, token)
);

create index if not exists submission_tokens_created_idx
  on public.submission_tokens (created_at);

alter table public.submission_tokens enable row level security;
-- Politika yok = yalnızca definer fonksiyonlar erişir.
revoke all on public.submission_tokens from public, anon, authenticated;

comment on table public.submission_tokens is
  'Çevrimdışı kuyruğun tekrar gönderimlerinde submit_review''in iki kez '
  'uygulanmasını engelleyen tek seferlik anahtarlar. Eski satırlar periyodik '
  'olarak silinebilir (created_at indeksi bunun için).';

-- ============================================================ ortak uygulayıcı
-- Tüm puanlama buradan geçer. Yalnızca definer fonksiyonlar çağırır (onlar
-- postgres olarak çalıştığı için EXECUTE'a ihtiyaç duymazlar).
create or replace function public.apply_progress(
  p_xp_delta int,
  p_activity boolean,
  -- Doluysa günlük hedef bonusunun alındığı gün olarak yazılır. Ayrı bir UPDATE
  -- yerine buradan geçiyor: profiles'a iki kez yazmak AFTER trigger'larını iki
  -- kez çalıştırırdı (kural 2).
  p_goal_date date default null
)
returns table (
  xp int, weekly_xp int, streak int, league text, xp_awarded int
)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid   uuid := auth.uid();
  v_today date := (now() at time zone 'Europe/Istanbul')::date;
  v_week  date := (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date;
  -- Tek çağrı tavanı: en büyük meşru tek kazanç günlük hedef bonusu (50).
  c_call  constant int := 60;
  -- Günlük tavan. GERÇEK KULLANIMDAN KALİBRE EDİLMELİ: çok düşük olursa dürüst
  -- kullanıcıyı sessizce keser. 150 doğru cevap/gün üst sınır olarak seçildi.
  c_day   constant int := 1500;
  v_today_xp int;
  v_weekly   int;
  v_add      int;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  -- Kilit: eşzamanlı çağrılar günlük tavanı aşamasın (kural 3).
  select case when p.xp_today_date = v_today then p.xp_today  else 0 end,
         case when p.week_start    = v_week  then p.weekly_xp else 0 end
    into v_today_xp, v_weekly
    from public.profiles p
   where p.id = v_uid
     for update;

  if not found then
    raise exception 'profil bulunamadı' using errcode = 'P0002';
  end if;

  v_add := least(
             greatest(coalesce(p_xp_delta, 0), 0),
             c_call,
             greatest(c_day - v_today_xp, 0)
           );

  -- TEK update (kural 2).
  update public.profiles p
     set xp            = p.xp + v_add,
         weekly_xp     = v_weekly + v_add,
         week_start    = v_week,
         xp_today      = v_today_xp + v_add,
         xp_today_date = v_today,
         -- Seri sunucuda türetiliyor: art arda günlerde büyür, gün atlanınca
         -- 1'e döner, aynı gün içinde değişmez. Bu aynı zamanda eski bir
         -- istemcinin 7 → 1 → 7 yazıp arkadaşlara sahte "seri" bildirimi
         -- göndermesi hatasını da kapatıyor.
         streak = case
                    when not p_activity                       then p.streak
                    when p.last_activity_date = v_today       then p.streak
                    when p.last_activity_date = v_today - 1   then p.streak + 1
                    else 1
                  end,
         last_activity_date = case when p_activity then v_today
                                   else p.last_activity_date end,
         daily_goal_date = coalesce(p_goal_date, p.daily_goal_date)
   where p.id = v_uid;

  return query
    select p.xp, p.weekly_xp, p.streak, p.league, v_add
      from public.profiles p where p.id = v_uid;
end
$fn$;

revoke execute on function public.apply_progress(int, boolean, date)
  from public, anon, authenticated;

-- ============================================================ havuz cevabı
-- Doğruluk SUNUCUDA belirlenir; istemci yalnızca hangi şıkkı işaretlediğini
-- söyler. Ölçüm satırları sorunun KENDİ konusundan yazılır, istemcinin
-- gönderdiği konudan değil.
create or replace function public.submit_pool_answer(
  p_mistake uuid,
  p_choice  int
)
returns table (
  correct boolean, correct_index int,
  xp int, weekly_xp int, streak int, league text, xp_awarded int
)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid     uuid := auth.uid();
  m         public.mistakes%rowtype;
  v_correct boolean;
  v_fresh   boolean := false;
  v_xp      int := 0;
  r         record;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  select * into m from public.mistakes where id = p_mistake;
  if not found then
    raise exception 'soru bulunamadı' using errcode = 'P0002';
  end if;
  -- Havuz kuralları: paylaşıma açık, moderasyondan geçmiş, kendi sorun değil.
  if not (m.is_public and m.moderation = 'ok' and m.user_id <> v_uid) then
    raise exception 'bu soru havuzda değil' using errcode = '42501';
  end if;
  if m.correct_index is null then
    raise exception 'sorunun cevabı tanımlı değil' using errcode = 'P0002';
  end if;

  v_correct := (p_choice = m.correct_index);

  -- Aynı soru ikinci kez XP vermez (PK çakışması). RETURNING ile gerçekten
  -- eklenip eklenmediğini anlıyoruz.
  insert into public.question_attempts (mistake_id, user_id, correct)
  values (p_mistake, v_uid, v_correct)
  on conflict do nothing
  returning true into v_fresh;

  if coalesce(v_fresh, false) then
    -- Ölçüm ana konu + ek konulara yazılır (harita ikisini birden doldurur).
    insert into public.study_attempts
      (user_id, subject, concept, exam, correct, source, mistake_id)
    select v_uid, m.subject, c, m.exam, v_correct, 'pool', m.id
      from unnest(array[m.concept] || coalesce(m.extra_concepts, '{}')) c
     where c is not null and btrim(c) <> '';

    if v_correct then v_xp := 10; end if;
  end if;

  select * into r from public.apply_progress(v_xp, true);
  return query select v_correct, m.correct_index, r.xp, r.weekly_xp,
                      r.streak, r.league, r.xp_awarded;
end
$fn$;

revoke execute on function public.submit_pool_answer(uuid, int) from public, anon;
grant  execute on function public.submit_pool_answer(uuid, int) to authenticated;

-- ==================================================== arkadaştan gelen cevap
create or replace function public.submit_sent_answer(
  p_send   uuid,
  p_choice int
)
returns table (
  correct boolean, correct_index int,
  xp int, weekly_xp int, streak int, league text, xp_awarded int
)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid     uuid := auth.uid();
  s         public.question_sends%rowtype;
  m         public.mistakes%rowtype;
  v_correct boolean;
  v_xp      int := 0;
  r         record;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  select * into s from public.question_sends where id = p_send;
  if not found or s.receiver_id <> v_uid then
    raise exception 'bu gönderi sana ait değil' using errcode = '42501';
  end if;

  select * into m from public.mistakes where id = s.mistake_id;
  if not found or m.correct_index is null then
    raise exception 'sorunun cevabı tanımlı değil' using errcode = 'P0002';
  end if;

  v_correct := (p_choice = m.correct_index);

  -- XP yalnızca İLK çözümde. Aynı soruyu tekrar göndermek serbest (0022), o
  -- yüzden her gönderi tekrar puan verseydi anlaşmalı iki kullanıcı XP
  -- basabilirdi. Kalan risk günlük tavanla sınırlı.
  if s.solved_at is null then
    insert into public.study_attempts
      (user_id, subject, concept, exam, correct, source, mistake_id)
    select v_uid, m.subject, c, m.exam, v_correct, 'sent', m.id
      from unnest(array[m.concept] || coalesce(m.extra_concepts, '{}')) c
     where c is not null and btrim(c) <> '';

    if v_correct then v_xp := 10; end if;
  end if;

  update public.question_sends
     set solved_at = coalesce(solved_at, now()),
         correct   = v_correct
   where id = p_send;

  select * into r from public.apply_progress(v_xp, true);
  return query select v_correct, m.correct_index, r.xp, r.weekly_xp,
                      r.streak, r.league, r.xp_awarded;
end
$fn$;

revoke execute on function public.submit_sent_answer(uuid, int) from public, anon;
grant  execute on function public.submit_sent_answer(uuid, int) to authenticated;

-- =========================================================== kendi tekrarın
-- DÜRÜST SINIR: burada doğruluk kaçınılmaz olarak ÖZNELDİR — kullanıcı kendi
-- fotoğrafına bakıp kendini notlandırıyor, sunucu bunu doğrulayamaz. Kazanç
-- şu: XP artık türetilmiş bir değer, doğrudan yazılabilir bir sayı değil.
-- Sahtelemek için binlerce RPC çağrısı gerekir ve günlük tavan onu sınırlar.
create or replace function public.submit_review(
  p_mistake uuid,
  p_correct boolean,
  -- Çevrimdışı kuyruğun ürettiği tek seferlik anahtar. Aynı anahtarla ikinci
  -- çağrı hiçbir şey uygulamaz, yalnızca güncel değerleri döndürür.
  p_token   uuid default null
)
returns table (
  xp int, weekly_xp int, streak int, league text, xp_awarded int
)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  m     public.mistakes%rowtype;
  v_xp  int := 0;
  r     record;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  if p_token is not null then
    insert into public.submission_tokens (user_id, token)
    values (v_uid, p_token)
    on conflict do nothing;
    if not found then
      -- Bu gönderim zaten uygulanmış (kuyruk tekrar denedi). Sessizce güncel
      -- değerleri döndür; ölçümü ve XP'yi İKİLEME.
      select * into r from public.apply_progress(0, false);
      return query select r.xp, r.weekly_xp, r.streak, r.league, r.xp_awarded;
      return;
    end if;
  end if;

  select * into m from public.mistakes where id = p_mistake;
  if not found or m.user_id <> v_uid then
    raise exception 'bu soru sana ait değil' using errcode = '42501';
  end if;

  insert into public.study_attempts
    (user_id, subject, concept, exam, correct, source, mistake_id)
  select v_uid, m.subject, c, m.exam, coalesce(p_correct, false), 'review', m.id
    from unnest(array[m.concept] || coalesce(m.extra_concepts, '{}')) c
   where c is not null and btrim(c) <> '';

  if coalesce(p_correct, false) then v_xp := 10; end if;

  select * into r from public.apply_progress(v_xp, true);
  return query select r.xp, r.weekly_xp, r.streak, r.league, r.xp_awarded;
end
$fn$;

revoke execute on function public.submit_review(uuid, boolean, uuid) from public, anon;
grant  execute on function public.submit_review(uuid, boolean, uuid) to authenticated;

-- ========================================================= günlük hedef bonusu
create or replace function public.claim_daily_goal()
returns table (
  xp int, weekly_xp int, streak int, league text, xp_awarded int
)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid    uuid := auth.uid();
  v_today  date := (now() at time zone 'Europe/Istanbul')::date;
  v_claimed date;
  v_done   int;
  r        record;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  -- Günde bir kez — kilitle, yoksa iki paralel çağrı iki bonus alır.
  select p.daily_goal_date into v_claimed
    from public.profiles p where p.id = v_uid for update;

  if v_claimed = v_today then
    -- Zaten alınmış: hata değil, sadece 0 ekle ve güncel değerleri döndür.
    select * into r from public.apply_progress(0, false);
    return query select r.xp, r.weekly_xp, r.streak, r.league, r.xp_awarded;
    return;
  end if;

  -- Bugün gerçekten çalışılmış mı? İstemcinin "hedefi tamamladım" beyanına
  -- güvenmiyoruz; en az bir ölçüm satırı aranıyor.
  --
  -- DÜRÜST SINIR: "hedefi tamamladı mı" kararı istemcide kalıyor, çünkü hedef
  -- dinamik (o gün planı gelen tekrar sayısına göre değişiyor) ve sunucu tekrar
  -- planlayıcısının durumunu bilmiyor. Sunucunun garanti ettiği şey daha dar
  -- ama net: günde EN FAZLA BİR KEZ ve ancak gerçekten çalışıldıysa.
  -- Kötüye kullanım tavanı bu yüzden 50 XP/gün.
  select count(*)::int into v_done
    from public.study_attempts a
   where a.user_id = v_uid
     and (a.created_at at time zone 'Europe/Istanbul')::date = v_today;

  if v_done = 0 then
    raise exception 'bugün hiç çalışılmamış' using errcode = '42501';
  end if;

  select * into r from public.apply_progress(50, false, v_today);
  return query select r.xp, r.weekly_xp, r.streak, r.league, r.xp_awarded;
end
$fn$;

revoke execute on function public.claim_daily_goal() from public, anon;
grant  execute on function public.claim_daily_goal() to authenticated;

-- ====================================================== paylaşımı aç / kapat
-- is_public artık UPDATE'te kilitli (bir sonraki göç); paylaşımı geri çekmek
-- meşru bir istek olduğu için buradan yapılıyor. Kaldırılmış içerik geri
-- açılamaz.
create or replace function public.set_question_sharing(
  p_mistake uuid,
  p_public  boolean
)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare m public.mistakes%rowtype;
begin
  select * into m from public.mistakes where id = p_mistake;
  if not found or m.user_id <> auth.uid() then
    raise exception 'bu soru sana ait değil' using errcode = '42501';
  end if;
  if p_public and m.moderation = 'removed' then
    raise exception 'kaldırılmış içerik havuza geri açılamaz'
      using errcode = '42501';
  end if;
  update public.mistakes set is_public = coalesce(p_public, false)
   where id = p_mistake;
end
$fn$;

revoke execute on function public.set_question_sharing(uuid, boolean) from public, anon;
grant  execute on function public.set_question_sharing(uuid, boolean) to authenticated;

-- ============================================================ profil yazımı
-- ensureProfile'ın upsert'ünün yerine. Upsert'ün hangi sütun ayrıcalıklarını
-- gerektirdiği belirsizliğini de ortadan kaldırıyor (ON CONFLICT DO UPDATE
-- listesine hangi kolonların girdiği sürüme bağlı).
create or replace function public.upsert_my_profile(
  p_nickname text,
  p_mascot   text default null
)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid  uuid := auth.uid();
  v_nick text := nullif(btrim(regexp_replace(coalesce(p_nickname, ''), '\s+', ' ', 'g')), '');
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if v_nick is null or char_length(v_nick) < 2 or char_length(v_nick) > 24 then
    raise exception 'Takma ad 2-24 karakter olmalı' using errcode = '22023';
  end if;
  if v_nick ~ '[[:cntrl:]]' then
    raise exception 'Takma adda geçersiz karakter var' using errcode = '22023';
  end if;
  -- Sistem hesabı kimliğinin taklidi (ör. 'ÖSYM Çıkmış Sorular') engellenir:
  -- o ad havuz künyesinde ve aramada resmî hesap gibi görünürdü.
  if exists (
    select 1 from public.profiles s
     where s.is_system and lower(s.nickname) = lower(v_nick)
  ) then
    raise exception 'Bu takma ad kullanılamaz' using errcode = '22023';
  end if;

  insert into public.profiles (id, nickname, mascot)
  values (v_uid, v_nick, p_mascot)
  on conflict (id) do update
     set nickname = excluded.nickname,
         mascot   = coalesce(excluded.mascot, public.profiles.mascot);
end
$fn$;

revoke execute on function public.upsert_my_profile(text, text) from public, anon;
grant  execute on function public.upsert_my_profile(text, text) to authenticated;
