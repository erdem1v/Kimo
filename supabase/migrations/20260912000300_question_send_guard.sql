-- 0081 — Soru gönderme: not sınırı, hız sınırı, tek çağrıda gönderim (Task 12 · P4)
--
-- ÜÇ AÇIĞI BİRDEN KAPATIYOR ve üçü de Tur 7 · n5'in gönderme akışını
-- çoğaltmasıyla kritik hâle geldi:
--
-- 1. `note` İÇİN VERİTABANI SINIRI YOKTU. 200 karakter yalnızca istemcide
--    (`send_question_sheet.dart` içindeki `maxLength: 200`) duruyordu; PostgREST'e
--    doğrudan istek atan bir yol SINIRSIZ uzunlukta metin yazabiliyordu.
--    Karar: 250 karakter, İKİ katmanda birden. Sayı değil sınırın YERİ önemli.
--
-- 2. HIZ SINIRI HİÇ YOKTU. 0022 unique kısıtı düşürdüğü için aynı soru aynı
--    kişiye sınırsız tekrar gidiyordu ve HER INSERT bir push tetikliyordu
--    (`on_question_sent`). Arkadaş olan biri için bu, tek çaresi engellemek olan
--    bir bildirim bombardımanı yüzeyiydi. n5 gönderme akışına iki yeni giriş
--    noktası ekliyor; sınır artık erteleyemez.
--
-- 3. GÖNDERİM ATOMİK DEĞİLDİ. İstemci alıcı başına ayrı INSERT atıyordu; ortada
--    bir hata olursa kısmi gönderim kalıyordu ve geri alma yoktu.
--
-- 0022 İLE İLİŞKİ: "aynı soruyu tekrar göndermeye izin ver" kararı
-- KALDIRILMIYOR, DARALTILIYOR. O karar unique kısıtın ikinci gönderimi
-- patlatmasını çözmek içindi; sınırsızlık amaç değildi.
--
-- GERİ ALMA: `drop function public.send_question_to_friends(uuid, uuid[], text);`
-- ve `alter table public.question_sends drop constraint question_sends_note_len;`
-- İstemci eski satır-satır INSERT yoluna döner (politika yerinde duruyor).

-- ====================================================== 1) not uzunluğu
-- `not valid` + `validate` İKİ ADIMLI, bilinçli: mevcut satırlar istemci 200
-- ile sınırlı olduğu için hepsi geçecek, ama göç beklenmedik uzun bir satır
-- yüzünden PATLAMASIN. Üretimde göçler elle uygulandığı için yarıda kalan bir
-- `alter table` en pahalı hata sınıfı.
--
-- SÜTUN EKLENMİYOR → `lockdown_v8` GEREKMİYOR. Lockdown'ın kolon sınıflandırma
-- döngüsü yalnızca yeni SÜTUNDA patlıyor; CHECK kısıtı onu tetiklemiyor.
alter table public.question_sends
  add constraint question_sends_note_len
  check (note is null or char_length(note) <= 250) not valid;

alter table public.question_sends
  validate constraint question_sends_note_len;

comment on column public.question_sends.note is
  'Gönderenin yazdığı kısa not, en fazla 250 karakter (CHECK ile zorunlu). '
  'Öğrencinin KENDİ notu (mistakes.note) gönderime HİÇ girmiyor — '
  'received_questions yalnızca bu alanı yayınlıyor.';

-- ====================================================== 2) hız sınırı sarmalayıcısı
-- `bump_rate_limit` HERKESTEN revoke; istemci onu doğrudan çağıramıyor, o
-- yüzden araya bu definer sarmalayıcı giriyor (deponun `add_friend_by_code`
-- deseninin aynısı).
--
-- BAŞARISIZLIK İSTİSNA DEĞİL DÖNÜŞ DEĞERİ. PostgreSQL'de istisna işlemi geri
-- alır — VE geri alma oran sınırı sayacını da siler. Yani reddedilen denemeler
-- hiç sayılmaz ve sınır yalnızca başarılı gönderimleri sınırlar
-- (20260902000700:154-163'ün aynı dersi, tests/120 onu sınıyor).
--
-- İKİ KOVA:
--   `qsend`            → günde en fazla `qsend_daily` (varsayılan 3) gönderim
--   `qsend:<alıcı>`    → aynı arkadaşa günde 1
-- Pencere anahtarı Istanbul GÜNÜ. Sayılar `app_config`'ten fail-open okunuyor,
-- yani göç gerektirmeden gevşetilebilir (0075'in kuralı).
insert into public.app_config (key, value) values
  ('qsend_daily',      '3'),
  ('qsend_per_friend', '1'),
  ('qsend_repeat_days','30')
on conflict (key) do nothing;

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

comment on function public.send_question_to_friends(uuid, uuid[], text) is
  'Bir soruyu birden çok arkadaşa TEK çağrıda gönderir. Günlük tavan + arkadaş '
  'başına tavan + aynı soruyu tekrar gönderme yasağı burada; arkadaşlık/engel/'
  'askı kontrolü RLS politikasında kalıyor (tek doğruluk kaynağı). '
  'Başarısızlık İSTİSNA DEĞİL sayı olarak dönüyor — istisna sayacı da geri alırdı.';

-- ====================================================== 3) gönderen avatarı
-- Tur 7 · n5 gelen kutusu kartında gönderenin avatarını istiyor; görünüm onu
-- döndürmüyordu ve arayüz baş harfe düşüyordu.
--
-- İLİŞKİ KAPISI SAĞLANIYOR: gönderen ZORUNLU olarak arkadaş
-- (`sends_insert_friend` politikası `are_friends` istiyor), yani bu, avatarı
-- yabancıya açmıyor. `can_read_avatar`ın arkadaşlık dalı da imzalı URL'yi
-- ayrıca kapılıyor — sütun tek başına bir dosya erişimi vermiyor.
--
-- Kolon listesi 0053'ten BİREBİR kopyalandı; tek fark `sp.avatar_path`. Üç
-- zorunlu alan (`photo_path`, `options`, `correct_index`) ve altı süzgeç
-- AYNEN duruyor: bu paketteki en olası regresyon onları yeniden yazarken
-- birini sessizce düşürmek olurdu.
--
-- SÜTUN EN SONA EKLENİYOR ve `create or replace view` kullanılıyor.
--
-- Bu paket önce DROP + CREATE yazıyordu, çünkü `create or replace view`
-- yalnızca listenin SONUNA sütun eklemeye izin veriyor ve `sender_avatar_path`
-- tasarımda `sender_mascot`ın yanına, gönderen kimliğinin arasına giriyordu.
-- O sürüm CI'da `supabase db reset`i BU DOSYADA durdurdu:
--   ERROR: cannot drop view received_questions because other objects depend on it
--   view my_daily_state depends on view received_questions
-- `my_daily_state` (0086) gelen kutusu sayısını buradan okuyor, yani görünüm
-- artık yaprak değil; düşürmek zincirin tamamını düşürmek demek.
--
-- İki çıkış vardı: (a) `my_daily_state`i de düşürüp yeniden kurmak,
-- (b) sütunu sona alıp yerinde değiştirmek. (b) seçildi: (a),
-- `my_daily_state`in gövdesini depoda ÜÇÜNCÜ kez kopyalardı ve bu paketin
-- kendi dersi zaten "kopyalanan gövde sessizce ıraksar"dı. Sıranın taşıdığı
-- tek şey okunabilirlikti; ne pgTAP (`has_column` sırasız) ne PostgREST
-- (ada göre JSON) ne de istemci (`row['sender_avatar_path']`) sıraya bakıyor.
--
-- `create or replace view` bağımlı görünümü de bozmuyor: `my_daily_state`in
-- saklı tanımı kendi sütun listesiyle donmuş durumda, sona eklenen sütun ona
-- ulaşmıyor.
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
  case when s.solved_at is not null then m.correct_index end as correct_index,
  sp.avatar_path      as sender_avatar_path
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

-- `create or replace view` grant'ları KORUYOR, yani bu iki satır teknik olarak
-- zorunlu değil. Yine de duruyorlar: 0068'in dersi, görünümü yeniden tanımlayan
-- bir göçün eski bir grant'ı farkında olmadan diriltebilmesiydi. Yetkiyi her
-- tanımın yanında açıkça yazmak, bir sonraki düzenleme DROP'a dönerse de doğru
-- kalan tek biçim.
revoke all on public.received_questions from public, anon;
grant select on public.received_questions to authenticated;
