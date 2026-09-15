-- test: supabase/tests/320_pair_streaks.sql
--
-- MUTASYON: `start_pair_streak`ten ASKI kapisini sok (bayrak kapisi yerinde
-- kaliyor — mutasyon tek korumayi bozmali).
-- BEKLENEN: 320'nin "ASKIDAKI kullanici ortak seri BASLATAMIYOR" iddiasi
-- kirmizi.
--
-- NEDEN BU BIR KORUMA: yaptirim tasarimi (0062) "kapanan tek sey URETIM"
-- diyor: fotograf yukleme, soru gonderme, arkadaslik istegi. Ortak seri Task
-- 12'de gelen YENI bir uretim/sosyal yuzey — karsi tarafa GORUNEN kalici bir
-- satir yaratiyor — ama askiyi hic sormuyordu.
--
-- NOT: iki govde de goc dosyasindan URETILDI. Kaynak: 0094.
create or replace function public.start_pair_streak(p_friend uuid)
returns boolean
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_a   uuid;
  v_b   uuid;
  v_n   int;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_friend is null or p_friend = v_uid then
    return false;
  end if;

  -- BAYRAK SUNUCUDA DA (0094). `ff_pair_streak` yalnızca İSTEMCİ tarafında
  -- uygulanıyordu: eski bir istemci sürümü ya da doğrudan RPC çağrısı seriyi
  -- başlatabiliyordu ve kapalı dönemde VERİ BİRİKMEYE devam ediyordu. Kapatma
  -- kararının gerekçesi DSA Md. 28(1) Kılavuzu — o gerekçe veri birikmesini de
  -- kapsıyor.
  if not public.config_bool('ff_pair_streak', false) then
    return false;
  end if;

  if not public.are_friends(v_uid, p_friend) then
    return false;
  end if;
  if public.is_blocked_between(v_uid, p_friend) then
    return false;
  end if;

  -- İKİ YÖNDE DE çözülmüş gönderim şartı.
  if not exists (
    select 1 from public.question_sends s
     where s.sender_id = v_uid and s.receiver_id = p_friend
       and s.solved_at is not null
  ) or not exists (
    select 1 from public.question_sends s
     where s.sender_id = p_friend and s.receiver_id = v_uid
       and s.solved_at is not null
  ) then
    return false;
  end if;

  v_a := least(v_uid, p_friend);
  v_b := greatest(v_uid, p_friend);

  if exists (select 1 from public.pair_streaks s
              where s.a_id = v_a and s.b_id = v_b) then
    return false;   -- zaten var
  end if;

  select count(*)::int into v_n
    from public.pair_streaks s
   where v_uid in (s.a_id, s.b_id);
  if v_n >= public.config_int('pair_streak_max', 3) then
    return false;
  end if;

  insert into public.pair_streaks (a_id, b_id, streak, best, last_day)
  values (v_a, v_b, 1, 1, public.istanbul_day())
  on conflict do nothing;
  return true;
end
$fn$;
revoke execute on function public.start_pair_streak(uuid) from public, anon;
grant  execute on function public.start_pair_streak(uuid) to authenticated;
-- @UNDO
create or replace function public.start_pair_streak(p_friend uuid)
returns boolean
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_a   uuid;
  v_b   uuid;
  v_n   int;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_friend is null or p_friend = v_uid then
    return false;
  end if;

  -- BAYRAK SUNUCUDA DA (0094). `ff_pair_streak` yalnızca İSTEMCİ tarafında
  -- uygulanıyordu: eski bir istemci sürümü ya da doğrudan RPC çağrısı seriyi
  -- başlatabiliyordu ve kapalı dönemde VERİ BİRİKMEYE devam ediyordu. Kapatma
  -- kararının gerekçesi DSA Md. 28(1) Kılavuzu — o gerekçe veri birikmesini de
  -- kapsıyor.
  if not public.config_bool('ff_pair_streak', false) then
    return false;
  end if;

  -- ASKI ÜRETİMİ DURDURUR (0062 kuralı). Ortak seri karşı tarafa GÖRÜNEN
  -- kalıcı bir satır yaratıyor, yani bir üretim yüzeyi; askıdaki kullanıcı
  -- aski öncesi çözülmüş gönderimlerle yeni seri başlatabiliyordu.
  if public.is_suspended(v_uid) then
    return false;
  end if;
  if not public.are_friends(v_uid, p_friend) then
    return false;
  end if;
  if public.is_blocked_between(v_uid, p_friend) then
    return false;
  end if;

  -- İKİ YÖNDE DE çözülmüş gönderim şartı.
  if not exists (
    select 1 from public.question_sends s
     where s.sender_id = v_uid and s.receiver_id = p_friend
       and s.solved_at is not null
  ) or not exists (
    select 1 from public.question_sends s
     where s.sender_id = p_friend and s.receiver_id = v_uid
       and s.solved_at is not null
  ) then
    return false;
  end if;

  v_a := least(v_uid, p_friend);
  v_b := greatest(v_uid, p_friend);

  if exists (select 1 from public.pair_streaks s
              where s.a_id = v_a and s.b_id = v_b) then
    return false;   -- zaten var
  end if;

  select count(*)::int into v_n
    from public.pair_streaks s
   where v_uid in (s.a_id, s.b_id);
  if v_n >= public.config_int('pair_streak_max', 3) then
    return false;
  end if;

  insert into public.pair_streaks (a_id, b_id, streak, best, last_day)
  values (v_a, v_b, 1, 1, public.istanbul_day())
  on conflict do nothing;
  return true;
end
$fn$;
revoke execute on function public.start_pair_streak(uuid) from public, anon;
grant  execute on function public.start_pair_streak(uuid) to authenticated;
