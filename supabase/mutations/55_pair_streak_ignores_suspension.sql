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
-- IDDIA ARTIK SEBEBI CIVILIYOR (0098): `is(..., 'suspended')`. Eskiden
-- `ok(not ...)` yaziyordu ve fonksiyon yedi sonucu tek `false`a katladigi icin
-- iddia YANLIS SEBEPLE de gecebiliyordu; dosyanin kendi notu bunu bir kez
-- yasamis (taze ikili sarti). Aski kapisi sokulunce fonksiyon 'started'
-- donuyor ve iddia kirmiziya doniyor.
--
-- GERI ALMA GOCUN BIREBIR KOPYASI (drop + create). `create or replace` ile
-- geri almak, check_sql'in 7. kontrolunde imza oneki farki uretiyor: canli
-- govde `create function`, geri alma `create or replace function` olurdu ve
-- kapi ikisini ayri metin sayardi.
--
-- NOT: iki govde de goc dosyasindan URETILDI. Kaynak: 0098.
create or replace function public.start_pair_streak(p_friend uuid)
returns text
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
    return 'not_eligible';
  end if;

  -- BAYRAK SUNUCUDA DA (0094). `ff_pair_streak` yalnızca İSTEMCİ tarafında
  -- uygulanıyordu: eski bir istemci sürümü ya da doğrudan RPC çağrısı seriyi
  -- başlatabiliyordu ve kapalı dönemde VERİ BİRİKMEYE devam ediyordu.
  if not public.config_bool('ff_pair_streak', false) then
    return 'disabled';
  end if;

  if not public.are_friends(v_uid, p_friend) then
    return 'not_eligible';
  end if;
  if public.is_blocked_between(v_uid, p_friend) then
    return 'not_eligible';
  end if;

  v_a := least(v_uid, p_friend);
  v_b := greatest(v_uid, p_friend);

  if exists (select 1 from public.pair_streaks s
              where s.a_id = v_a and s.b_id = v_b) then
    return 'exists';
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
    return 'needs_solved';
  end if;

  select count(*)::int into v_n
    from public.pair_streaks s
   where v_uid in (s.a_id, s.b_id);
  if v_n >= public.config_int('pair_streak_max', 3) then
    return 'cap';
  end if;

  insert into public.pair_streaks (a_id, b_id, streak, best, last_day)
  values (v_a, v_b, 1, 1, public.istanbul_day())
  on conflict do nothing;
  return 'started';
end
$fn$;
-- @UNDO
drop function if exists public.start_pair_streak(uuid);

create function public.start_pair_streak(p_friend uuid)
returns text
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
    return 'not_eligible';
  end if;

  -- BAYRAK SUNUCUDA DA (0094). `ff_pair_streak` yalnızca İSTEMCİ tarafında
  -- uygulanıyordu: eski bir istemci sürümü ya da doğrudan RPC çağrısı seriyi
  -- başlatabiliyordu ve kapalı dönemde VERİ BİRİKMEYE devam ediyordu.
  if not public.config_bool('ff_pair_streak', false) then
    return 'disabled';
  end if;

  -- ASKI ÜRETİMİ DURDURUR (0062 kuralı). Ortak seri karşı tarafa GÖRÜNEN
  -- kalıcı bir satır yaratıyor, yani bir üretim yüzeyi.
  if public.is_suspended(v_uid) then
    return 'suspended';
  end if;
  if not public.are_friends(v_uid, p_friend) then
    return 'not_eligible';
  end if;
  if public.is_blocked_between(v_uid, p_friend) then
    return 'not_eligible';
  end if;

  v_a := least(v_uid, p_friend);
  v_b := greatest(v_uid, p_friend);

  if exists (select 1 from public.pair_streaks s
              where s.a_id = v_a and s.b_id = v_b) then
    return 'exists';
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
    return 'needs_solved';
  end if;

  select count(*)::int into v_n
    from public.pair_streaks s
   where v_uid in (s.a_id, s.b_id);
  if v_n >= public.config_int('pair_streak_max', 3) then
    return 'cap';
  end if;

  insert into public.pair_streaks (a_id, b_id, streak, best, last_day)
  values (v_a, v_b, 1, 1, public.istanbul_day())
  on conflict do nothing;
  return 'started';
end
$fn$;

revoke execute on function public.start_pair_streak(uuid) from public, anon;
grant  execute on function public.start_pair_streak(uuid) to authenticated;
