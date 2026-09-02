-- 0041 — Seri çarpanı (kombo) ve XP ekonomisinin yeniden kalibrasyonu
--
-- NEDEN: onaylanan tasarım pratik ekranında bir çarpan rozeti (×3) ve oturum
-- sonunda "en uzun seri ×5" gösteriyor. Kural açık: **arayüzde gösterilen her
-- mekanik sunucuda gerçekten uygulanmalı.** Çarpan bugüne kadar hiç yoktu;
-- ya uygulanacaktı ya da gösterilmeyecekti. Uygulanıyor.
--
-- KOMBO TANIMI:
--   • Her DOĞRU cevapta artar, YANLIŞTA sıfırlanır.
--   • Son doğru cevabın üzerinden 30 dakika geçtiyse yeniden 1'den başlar.
--     "Oturum" kavramı böyle kuruluyor — istemcide zamanlayıcı yok, ölçüt
--     sunucudaki `combo_at`.
--   • Çarpan `least(greatest(kombo,1), 5)`; XP = 10 × çarpan.
--
-- OTURUMUN EN UZUN KOMBOSU İSTEMCİDE TÜRETİLİYOR: her yanıtta dönen `combo`
-- değerinin o oturumdaki maksimumu. Bunun için yeni bir sunucu durumu yok.
--
-- GÜNLÜK TAVAN 1500 → 3000: çarpanla birlikte dürüst bir kullanıcının günlük
-- kazancı beşe kadar katlanabiliyor; eski tavan onu sessizce keserdi.
-- UYARI: 3000 de ÖLÇÜLMÜŞ bir sayı değil. Task 01 aynı uyarıyı 1500 için
-- yapmıştı; gerçek p99 günlük XP ölçülüp güncellenmeli.
--
-- ARTIK RİSK, AÇIKÇA: şıkkı olmayan (kendi kendine notlanan) tekrarlarda
-- doğruluk hâlâ kullanıcı beyanı ve çarpan o beyanın değerini 5 katına
-- çıkarıyor. Günlük tavan bunu SINIRLIYOR, sıfırlamıyor. Şıkkı olan sorularda
-- doğruluk artık sunucuda hesaplanıyor (aşağıda `p_choice`).

alter table public.profiles
  add column if not exists combo    int not null default 0,
  add column if not exists combo_at timestamptz;

comment on column public.profiles.combo is
  'Ardışık doğru cevap sayısı. 30 dakika sessizlikten sonra sıfırlanır. '
  'XP çarpanı buradan türetilir; istemci yazamaz.';
comment on column public.profiles.combo_at is
  'Komboyu ilerleten son doğru cevabın zamanı. Oturum penceresi bununla '
  'ölçülüyor — istemci saatiyle değil.';

-- ============================================================ ortak uygulayıcı
-- İmza DEĞİŞTİĞİ için önce düşürülüyor. `create or replace` ile yeni parametre
-- eklemek İKİNCİ bir aşırı yükleme yaratır ve iki argümanlı çağrılar
-- "function is not unique" ile patlar — depoda bu tuzağa iki kez düşülmüş
-- (0014/0015 ve 0016/0024).
--
-- plpgsql gövdeleri fonksiyon çağrılarını ÇALIŞMA ANINDA çözdüğü için
-- `submit_*` fonksiyonlarını bu düşürme kırmıyor; yeter ki yenisi aynı işlem
-- içinde yaratılsın.
drop function if exists public.apply_progress(int, boolean, date);

create or replace function public.apply_progress(
  p_xp_delta int,
  p_activity boolean,
  p_goal_date date default null,
  -- null  → kombo hiç değişmez (hedef bonusu, yalnızca okuma çağrıları)
  -- true  → kombo ilerler, çarpan uygulanır
  -- false → kombo sıfırlanır, çarpan uygulanmaz
  p_correct boolean default null
)
returns table (
  xp int, weekly_xp int, streak int, league text, xp_awarded int,
  combo int, multiplier int
)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid   uuid := auth.uid();
  v_today date := (now() at time zone 'Europe/Istanbul')::date;
  v_week  date := (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date;
  -- Tek çağrı tavanı. En büyük meşru tek kazanç: 10 × 5 = 50 (kombo tavanı)
  -- ve günlük hedef bonusu 50. 60 ikisini de kapsıyor.
  c_call   constant int := 60;
  -- Günlük tavan — bkz. başlıktaki uyarı.
  c_day    constant int := 3000;
  -- Kombo çarpanının tavanı. Tasarımda en yüksek gösterilen değer ×5.
  c_combo  constant int := 5;
  -- Bu süre sessiz kalınırsa kombo yeniden 1'den başlar.
  c_window constant interval := interval '30 minutes';
  v_today_xp int;
  v_weekly   int;
  v_combo    int;
  v_combo_at timestamptz;
  v_mult     int := 1;
  v_add      int;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  -- Kilit: eşzamanlı çağrılar hem günlük tavanı hem komboyu bozmasın.
  select case when p.xp_today_date = v_today then p.xp_today  else 0 end,
         case when p.week_start    = v_week  then p.weekly_xp else 0 end,
         p.combo,
         p.combo_at
    into v_today_xp, v_weekly, v_combo, v_combo_at
    from public.profiles p
   where p.id = v_uid
     for update;

  if not found then
    raise exception 'profil bulunamadı' using errcode = 'P0002';
  end if;

  -- Yeni kombo değeri, tek yerde hesaplanıyor: hem çarpan hem UPDATE aynı
  -- sayıyı kullansın. İkiye bölünse "gösterilen çarpan" ile "verilen XP"
  -- ayrışırdı — tam olarak kaçınmaya çalıştığımız şey.
  if p_correct is null then
    v_combo := coalesce(v_combo, 0);
  elsif not p_correct then
    v_combo := 0;
  elsif v_combo_at is null or v_combo_at < now() - c_window then
    v_combo := 1;
  else
    v_combo := coalesce(v_combo, 0) + 1;
  end if;

  if coalesce(p_correct, false) then
    v_mult := least(greatest(v_combo, 1), c_combo);
  end if;

  v_add := least(
             greatest(coalesce(p_xp_delta, 0), 0) * v_mult,
             c_call,
             greatest(c_day - v_today_xp, 0)
           );

  -- TEK update: ikiye bölünürse sync_league_member_xp ve on_friend_milestone
  -- AFTER trigger'ları iki kez çalışır (Task 01, kural 2).
  update public.profiles p
     set xp            = p.xp + v_add,
         weekly_xp     = v_weekly + v_add,
         week_start    = v_week,
         xp_today      = v_today_xp + v_add,
         xp_today_date = v_today,
         combo         = v_combo,
         combo_at      = case when p_correct is null then p.combo_at
                              else now() end,
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
    select p.xp, p.weekly_xp, p.streak, p.league, v_add, p.combo, v_mult
      from public.profiles p where p.id = v_uid;
end
$fn$;

revoke execute on function public.apply_progress(int, boolean, date, boolean)
  from public, anon, authenticated;

-- ====================================================== arkadaş sorusu cevabı
-- Doğruluk zaten sunucuda hesaplanıyordu; artık komboyu da ilerletiyor.
-- Dönüş tipi değiştiği için `create or replace` yetmiyor, düşürülüyor.
drop function if exists public.submit_sent_answer(uuid, int);

create or replace function public.submit_sent_answer(
  p_send   uuid,
  p_choice int
)
returns table (
  correct boolean, correct_index int,
  xp int, weekly_xp int, streak int, league text, xp_awarded int,
  combo int, multiplier int
)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid     uuid := auth.uid();
  s         public.question_sends%rowtype;
  m         public.mistakes%rowtype;
  v_correct boolean;
  v_first   boolean;
  v_xp      int := 0;
  r         record;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  select * into s from public.question_sends where id = p_send;
  if not found or s.receiver_id <> v_uid then
    raise exception 'bu gönderim sana ait değil' using errcode = '42501';
  end if;

  select * into m from public.mistakes where id = s.mistake_id;
  if not found or m.correct_index is null then
    raise exception 'sorunun cevabı tanımlı değil' using errcode = 'P0002';
  end if;

  v_correct := (p_choice = m.correct_index);
  -- XP ve ölçüm YALNIZCA ilk çözümde. Aynı soru aynı kişiye yeniden
  -- gönderilebiliyor (0022); yeniden puanlamak iki kullanıcının anlaşarak XP
  -- üretmesine kapı açardı.
  v_first := s.solved_at is null;

  if v_first then
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

  if v_first then
    select * into r from public.apply_progress(v_xp, true, null, v_correct);
  else
    select * into r from public.apply_progress(0, false);
  end if;

  return query select v_correct, m.correct_index,
                      r.xp, r.weekly_xp, r.streak, r.league, r.xp_awarded,
                      r.combo, r.multiplier;
end
$fn$;

revoke execute on function public.submit_sent_answer(uuid, int) from public, anon;
grant  execute on function public.submit_sent_answer(uuid, int) to authenticated;

-- ============================================================ tekrar cevabı
-- İKİ DEĞİŞİKLİK:
--   1. Kombo ilerliyor.
--   2. `p_choice` eklendi. Sorunun şıkları varsa doğruluğu SUNUCU hesaplıyor ve
--      `p_correct` YOK SAYILIYOR. Çarpan, kullanıcı beyanının değerini beşe
--      katladığı için doğrulanabilir yerde doğrulamak şart oldu.
--      Şıkkı olmayan sorularda eski davranış korunuyor (beyan).
--
-- İmza değiştiği için düşürülüyor: `p_choice` eklemek aksi hâlde ikinci bir
-- aşırı yükleme yaratır ve üç argümanlı çağrılar belirsizleşir.
drop function if exists public.submit_review(uuid, boolean, uuid);

create or replace function public.submit_review(
  p_mistake uuid,
  p_correct boolean,
  -- Şıkkı olan sorularda işaretlenen şık. Verilirse doğruluğu sunucu belirler.
  p_choice  int default null,
  -- Çevrimdışı kuyruğun ürettiği tek seferlik anahtar.
  p_token   uuid default null
)
returns table (
  xp int, weekly_xp int, streak int, league text, xp_awarded int,
  combo int, multiplier int, correct boolean
)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid     uuid := auth.uid();
  m         public.mistakes%rowtype;
  v_correct boolean;
  v_xp      int := 0;
  r         record;
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
      -- değerleri döndür; ölçümü, XP'yi ve KOMBOYU ikileme.
      select * into r from public.apply_progress(0, false);
      return query select r.xp, r.weekly_xp, r.streak, r.league, r.xp_awarded,
                          r.combo, r.multiplier, coalesce(p_correct, false);
      return;
    end if;
  end if;

  select * into m from public.mistakes where id = p_mistake;
  if not found or m.user_id <> v_uid then
    raise exception 'bu soru sana ait değil' using errcode = '42501';
  end if;

  -- Doğrulanabiliyorsa doğrula; değilse beyanı kabul et.
  if m.correct_index is not null and p_choice is not null then
    v_correct := (p_choice = m.correct_index);
  else
    v_correct := coalesce(p_correct, false);
  end if;

  insert into public.study_attempts
    (user_id, subject, concept, exam, correct, source, mistake_id)
  select v_uid, m.subject, c, m.exam, v_correct, 'review', m.id
    from unnest(array[m.concept] || coalesce(m.extra_concepts, '{}')) c
   where c is not null and btrim(c) <> '';

  if v_correct then v_xp := 10; end if;

  select * into r from public.apply_progress(v_xp, true, null, v_correct);
  return query select r.xp, r.weekly_xp, r.streak, r.league, r.xp_awarded,
                      r.combo, r.multiplier, v_correct;
end
$fn$;

revoke execute on function public.submit_review(uuid, boolean, int, uuid)
  from public, anon;
grant  execute on function public.submit_review(uuid, boolean, int, uuid)
  to authenticated;
