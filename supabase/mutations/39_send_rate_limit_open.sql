-- test: supabase/tests/085_question_sends.sql
--
-- MUTASYON: hız sınırlarını söküp gönderimi sınırsız bırak.
-- BEKLENEN: 085'in "aynı soru 30 gün içinde tekrar gitmiyor", "arkadaş başına
-- günlük tavan" ve "günlük tavan dolunca kalan alıcılar denenmiyor" iddiaları
-- kırmızı.
--
-- NEDEN BU BİR KORUMA: 0022 unique kısıtı düşürdüğünden beri aynı soru aynı
-- kişiye SINIRSIZ tekrar gidebiliyordu ve HER INSERT bir push tetikliyordu
-- (`on_question_sent`). Arkadaş olan biri için bu, tek çaresi engellemek olan
-- bir bildirim bombardımanı yüzeyiydi. Tur 7 · n5 gönderme akışına iki yeni
-- giriş noktası eklediği için sınır artık ertelenemez.
-- NOT: iki govde de goc dosyasindan URETILDI, elle kopyalanmadi. Kaynak:
-- supabase/migrations/20260912000300_question_send_guard.sql (0081).
-- ILK YAZIMDA @UNDO BAYATLAMISTI: Task 13 fonksiyonun govdesine
-- politikanin alti kosulunu ekledi (definer RLS'i atliyor) ve geri alma
-- o kosullari SILIYORDU. `tools/check_sql.py` artik bunu yakaliyor.
create or replace function public.send_question_to_friends(
  p_mistake   uuid,
  p_receivers uuid[],
  p_note      text default null
)
returns table (sent int, blocked int, reason text)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid      uuid := auth.uid();
  v_day      text;
  v_note     text;
  v_repeat   int;
  v_sent     int  := 0;
  v_blocked  int  := 0;
  r          uuid;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_receivers is null or array_length(p_receivers, 1) is null then
    return query select 0, 0, 'no_receivers'::text;
    return;
  end if;
  -- ÜST SINIR: tek çağrıda kaç alıcı. Arkadaş listesi tipik olarak çok
  -- altında; sınır, tek istekle bütün listeye basmayı ucuzlatmamak için.
  if array_length(p_receivers, 1) > 20 then
    raise exception 'En fazla 20 alıcı' using errcode = '22023';
  end if;

  v_note := nullif(btrim(coalesce(p_note, '')), '');
  if v_note is not null and char_length(v_note) > 250 then
    raise exception 'Not en fazla 250 karakter' using errcode = '22023';
  end if;

  v_day    := public.istanbul_day()::text;
  v_repeat := public.config_int('qsend_repeat_days', 30);

  -- ================================================== RLS BURADA ATLANIYOR
  -- Bu fonksiyon SECURITY DEFINER, yani tablo sahibinin (postgres) yetkisiyle
  -- kosuyor ve `question_sends` uzerindeki `sends_insert_friend` politikasi
  -- DEGERLENDIRILMIYOR. Depo bu gercegi baska iki yerde zaten yaziyor:
  --   0062 (sanctions.sql:517) ve 0063 (guardian_removal.sql:79-81):
  --   "`add_friend_by_code` SECURITY DEFINER ve RLS'i atliyor — politika
  --    dogrudan INSERT yolunu, fonksiyondaki kontrol RPC yolunu kapatiyor."
  -- Depoda hicbir yerde `force row level security` YOK.
  --
  -- Dolayisiyla politikanin ALTI KOSULU burada ACIKCA tekrarlanmak zorunda.
  -- Tekrarlanmasaydi `p_mistake` keyfi bir uuid oldugu icin kullanici
  -- BASKASININ (ya da moderasyonda isaretlenmis, ya da taramasi bitmemis) bir
  -- hata satirini arkadaslarina gonderebilirdi.
  --
  -- Gonderen-tarafi uc kosul dongunun DISINDA, bir kez: alici degistikce
  -- degismiyorlar.
  if public.is_suspended(v_uid) then
    return query select 0, coalesce(array_length(p_receivers, 1), 0),
                        'suspended'::text;
    return;
  end if;

  if exists (select 1 from public.profiles p
              where p.id = v_uid and p.is_anonymous) then
    return query select 0, coalesce(array_length(p_receivers, 1), 0),
                        'anonymous'::text;
    return;
  end if;

  -- SAHIPLIK + icerik kapisi. `mistakes` uzerindeki RLS de atlandigi icin
  -- `m.user_id = v_uid` kosulu burada tek savunma.
  if not exists (
    select 1 from public.mistakes m
     where m.id = p_mistake
       and m.user_id = v_uid
       and m.moderation = 'ok'
       and m.photo_scan = 'clear'
  ) then
    return query select 0, coalesce(array_length(p_receivers, 1), 0),
                        'not_sendable'::text;
    return;
  end if;

  -- Alıcı başına tek tek: biri sınıra çarparsa DİĞERLERİ GİTMELİ. Tek
  -- ifadede toplu insert, bir alıcının kendi kovasını doldurması yüzünden
  -- bütün gönderimi düşürürdü.
  foreach r in array p_receivers loop
    if r = v_uid then
      v_blocked := v_blocked + 1;
      continue;
    end if;

    -- Alici-tarafi iki kosul (bkz. yukaridaki "RLS BURADA ATLANIYOR" notu).
    -- `are_friends` bu gocte HENUZ engel-farkinda degil, bu yuzden engel
    -- kontrolu ayrica yaziliyor — deponun her sosyal yuzeyde tekrarladigi kural.
    if not public.are_friends(v_uid, r)
       or public.is_blocked_between(v_uid, r) then
      v_blocked := v_blocked + 1;
      continue;
    end if;

    -- INSERT. Politikanin alti kosulu YUKARIDA tekrarlandi (definer fonksiyon
    -- RLS'i atliyor). Asagidaki `exception` dali yine de duruyor: dogrudan
    -- INSERT yolunda politika hala tek dogruluk kaynagi ve ileride buraya
    -- eklenen bir kosul once orada yakalanir.
    begin
      insert into public.question_sends (sender_id, receiver_id, mistake_id, note)
      values (v_uid, r, p_mistake, v_note);
      v_sent := v_sent + 1;
    exception
      when insufficient_privilege or unique_violation then
        v_blocked := v_blocked + 1;
    end;
  end loop;

  return query select v_sent, v_blocked,
                      case when v_sent > 0 then 'ok' else 'none' end::text;
end
$fn$;
revoke execute on function public.send_question_to_friends(uuid, uuid[], text)
  from public, anon;
grant  execute on function public.send_question_to_friends(uuid, uuid[], text)
  to authenticated;
-- @UNDO
create or replace function public.send_question_to_friends(
  p_mistake   uuid,
  p_receivers uuid[],
  p_note      text default null
)
returns table (sent int, blocked int, reason text)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid      uuid := auth.uid();
  v_day      text;
  v_note     text;
  v_repeat   int;
  v_sent     int  := 0;
  v_blocked  int  := 0;
  r          uuid;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_receivers is null or array_length(p_receivers, 1) is null then
    return query select 0, 0, 'no_receivers'::text;
    return;
  end if;
  -- ÜST SINIR: tek çağrıda kaç alıcı. Arkadaş listesi tipik olarak çok
  -- altında; sınır, tek istekle bütün listeye basmayı ucuzlatmamak için.
  if array_length(p_receivers, 1) > 20 then
    raise exception 'En fazla 20 alıcı' using errcode = '22023';
  end if;

  v_note := nullif(btrim(coalesce(p_note, '')), '');
  if v_note is not null and char_length(v_note) > 250 then
    raise exception 'Not en fazla 250 karakter' using errcode = '22023';
  end if;

  v_day    := public.istanbul_day()::text;
  v_repeat := public.config_int('qsend_repeat_days', 30);

  -- ================================================== RLS BURADA ATLANIYOR
  -- Bu fonksiyon SECURITY DEFINER, yani tablo sahibinin (postgres) yetkisiyle
  -- kosuyor ve `question_sends` uzerindeki `sends_insert_friend` politikasi
  -- DEGERLENDIRILMIYOR. Depo bu gercegi baska iki yerde zaten yaziyor:
  --   0062 (sanctions.sql:517) ve 0063 (guardian_removal.sql:79-81):
  --   "`add_friend_by_code` SECURITY DEFINER ve RLS'i atliyor — politika
  --    dogrudan INSERT yolunu, fonksiyondaki kontrol RPC yolunu kapatiyor."
  -- Depoda hicbir yerde `force row level security` YOK.
  --
  -- Dolayisiyla politikanin ALTI KOSULU burada ACIKCA tekrarlanmak zorunda.
  -- Tekrarlanmasaydi `p_mistake` keyfi bir uuid oldugu icin kullanici
  -- BASKASININ (ya da moderasyonda isaretlenmis, ya da taramasi bitmemis) bir
  -- hata satirini arkadaslarina gonderebilirdi.
  --
  -- Gonderen-tarafi uc kosul dongunun DISINDA, bir kez: alici degistikce
  -- degismiyorlar.
  if public.is_suspended(v_uid) then
    return query select 0, coalesce(array_length(p_receivers, 1), 0),
                        'suspended'::text;
    return;
  end if;

  if exists (select 1 from public.profiles p
              where p.id = v_uid and p.is_anonymous) then
    return query select 0, coalesce(array_length(p_receivers, 1), 0),
                        'anonymous'::text;
    return;
  end if;

  -- SAHIPLIK + icerik kapisi. `mistakes` uzerindeki RLS de atlandigi icin
  -- `m.user_id = v_uid` kosulu burada tek savunma.
  if not exists (
    select 1 from public.mistakes m
     where m.id = p_mistake
       and m.user_id = v_uid
       and m.moderation = 'ok'
       and m.photo_scan = 'clear'
  ) then
    return query select 0, coalesce(array_length(p_receivers, 1), 0),
                        'not_sendable'::text;
    return;
  end if;

  -- Alıcı başına tek tek: biri sınıra çarparsa DİĞERLERİ GİTMELİ. Tek
  -- ifadede toplu insert, bir alıcının kendi kovasını doldurması yüzünden
  -- bütün gönderimi düşürürdü.
  foreach r in array p_receivers loop
    if r = v_uid then
      v_blocked := v_blocked + 1;
      continue;
    end if;

    -- Alici-tarafi iki kosul (bkz. yukaridaki "RLS BURADA ATLANIYOR" notu).
    -- `are_friends` bu gocte HENUZ engel-farkinda degil, bu yuzden engel
    -- kontrolu ayrica yaziliyor — deponun her sosyal yuzeyde tekrarladigi kural.
    if not public.are_friends(v_uid, r)
       or public.is_blocked_between(v_uid, r) then
      v_blocked := v_blocked + 1;
      continue;
    end if;

    -- Aynı soru aynı kişiye `qsend_repeat_days` içinde tekrar gitmiyor.
    if exists (
      select 1 from public.question_sends s
       where s.sender_id = v_uid
         and s.receiver_id = r
         and s.mistake_id = p_mistake
         and s.created_at > now() - make_interval(days => v_repeat)
    ) then
      v_blocked := v_blocked + 1;
      continue;
    end if;

    if not public.bump_rate_limit(
             'qsend:' || r::text,
             public.config_int('qsend_per_friend', 1),
             v_day) then
      v_blocked := v_blocked + 1;
      continue;
    end if;

    if not public.bump_rate_limit(
             'qsend',
             public.config_int('qsend_daily', 3),
             v_day) then
      -- GÜNLÜK TAVAN: kalan alıcıları denemenin anlamı yok.
      return query select v_sent, v_blocked + 1, 'daily_limit'::text;
      return;
    end if;

    -- INSERT. Politikanin alti kosulu YUKARIDA tekrarlandi (definer fonksiyon
    -- RLS'i atliyor). Asagidaki `exception` dali yine de duruyor: dogrudan
    -- INSERT yolunda politika hala tek dogruluk kaynagi ve ileride buraya
    -- eklenen bir kosul once orada yakalanir.
    begin
      insert into public.question_sends (sender_id, receiver_id, mistake_id, note)
      values (v_uid, r, p_mistake, v_note);
      v_sent := v_sent + 1;
    exception
      when insufficient_privilege or unique_violation then
        v_blocked := v_blocked + 1;
    end;
  end loop;

  return query select v_sent, v_blocked,
                      case when v_sent > 0 then 'ok' else 'none' end::text;
end
$fn$;
revoke execute on function public.send_question_to_friends(uuid, uuid[], text)
  from public, anon;
grant  execute on function public.send_question_to_friends(uuid, uuid[], text)
  to authenticated;
