-- 0098 — `start_pair_streak` SEBEBİ döndürüyor (Task 17)
--
-- BULGU: fonksiyon YEDİ farklı sonucu tek bir `false`a katlıyordu — kendine
-- gönderme, bayrak kapalı, askı, arkadaş değil, engelli, iki yönde çözülmüş
-- gönderim yok, zaten var, üst sınır doldu. İstemci `false`u tek anlamda
-- okuyup "sen de ona bir soru gönder, ortak seriniz başlasın" çağrısını
-- gösteriyor.
--
-- İKİ SOMUT SONUÇ:
--
-- 1. Serisi ZATEN BAŞLAMIŞ ikiliye "başlatın" çağrısı çıkıyordu. Çağrıyı
--    yazan dosyanın kendi yorumu bunu yasaklıyor ("Tersi olsaydı seri zaten
--    başlamış bir ikiliye 'başlat' çağrısı gösterilirdi") ama `false` o
--    durumu da taşıdığı için kural uygulanamıyordu.
-- 2. Üst sınıra çarpan kullanıcıya da aynı çağrı çıkıyor ve ne yaparsa
--    yapsın seri başlamıyordu.
--
-- SEBEP KÜMESİ BİLEREK KABA. `not_eligible` üç durumu birden taşıyor:
-- kendine gönderme, arkadaş olmama ve engel. Engeli ayrı kod olarak
-- sızdırmak, deponun `add_friend_by_code`'daki tek-mesaj ilkesini bozardı —
-- karşı tarafın seni engellediğini öğrenmenin bir yolu olmamalı.
--
-- BÜTÜN KAPILAR KORUNUYOR. 0094'ün eklediği iki kapı — sunucu tarafı
-- `ff_pair_streak` bayrağı ve askı — aynen duruyor ve artık kendi sebeplerini
-- taşıyor. (Bu göçün ilk taslağı ikisini de düşürmüştü; `check_sql`in bayat
-- @UNDO kontrolü yakaladı.)
--
-- "ZATEN VAR" KONTROLÜ ÖNE ALINDI. Eski sırada "iki yönde çözülmüş gönderim"
-- şartı önce geliyordu; `question_sends` satırları silinmiş (soru silindi, ya
-- da karşı taraf hesabını kapattı) ama serisi duran bir ikilide fonksiyon
-- `needs_solved` derdi — yani var olan bir seri için "henüz başlamadı".
--
-- DROP + CREATE, `create or replace` DEĞİL: dönüş tipi `boolean`dan `text`e
-- değişiyor. Fonksiyon hiçbir görünüm ya da fonksiyon içinden çağrılmıyor.
--
-- DROP GRANT'I SİLER: alttaki iki satır zorunlu.
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

comment on function public.start_pair_streak(uuid) is
  'Ortak seriyi başlatır ve SEBEBİ döndürür (0098): started | exists | '
  'needs_solved | cap | suspended | disabled | not_eligible. `not_eligible` '
  'üç durumu bilerek birleştiriyor (kendine, arkadaş değil, engelli) — '
  'engeli ayrı kod olarak sızdırmak karşı tarafın engellediğini öğrenmenin '
  'yolu olurdu.';
