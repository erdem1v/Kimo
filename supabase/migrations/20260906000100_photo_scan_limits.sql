-- 0066 — Fotoğraf taraması: gerçek tür, boyut sınırı, terminal durum
--
-- ÜÇ AYRI DELİK, TEK KÖK: `scan-photos` depodan indirdiği baytın ne olduğunu
-- hiç sormuyordu.
--
--   (1) MIME sabit `image/jpeg` yazılıyordu. PNG/WebP yüklenince OpenAI
--       moderation isteği reddediliyor, satır `pending` KALIYOR ve süpürücü
--       on dakikada bir aynı indirmeyi boşuna tekrarlıyordu — sonsuz kuyruk.
--   (2) Boyut kapısı yoktu. `analyze-question` 8 MB'da duruyor (MAX_BASE64),
--       tarama tarafında karşılığı yoktu; kova da sınırsız kurulmuştu.
--   (3) `pending` dışında terminal bir "taranamadı" durumu yoktu. Böyle bir
--       satırı `flagged` yapmak YANLIŞ olurdu: 0062'nin ihlal tetikleyicisi
--       `flagged`'da ateşliyor ve kullanıcı, dosya biçimi yüzünden yaptırım
--       merdivenine girerdi.
--
-- BU GÖÇ: (3)'ü çözüyor — `unsupported` terminal durumu — ve (2)'yi kapıda
-- kesiyor: kova artık türü ve boyutu kendisi reddediyor. (1) fonksiyon
-- tarafında (`supabase/functions/scan-photos/index.ts`).
--
-- `unsupported` NEDEN GÜVENLİ: bütün paylaşım kapıları POZİTİF yazılmış
-- (`photo_scan = 'clear'`) — public_questions (0050), is_blocked_between
-- yolundaki gönderim görünümü (0053b:59) ve sends_insert_friend (0062:511).
-- Yeni değer hiçbirinde eşleşmiyor, yani satır sahibine açık / paylaşıma
-- kapalı kalıyor; tam olarak `pending` gibi davranıyor. Farkı: süpürücünün
-- kısmi index'i `where photo_scan = 'pending'` olduğu için kuyruktan ÇIKIYOR.

-- ------------------------------------------------------- durum makinesi
-- Kısıt adı 0050'de otomatik üretildi; ada güvenmek yerine photo_scan'e
-- bakan CHECK kısıtlarını katalogdan bulup düşürüyoruz.
do $mig$
declare r record;
begin
  for r in
    select con.conname
      from pg_constraint con
     where con.conrelid = 'public.mistakes'::regclass
       and con.contype = 'c'
       and pg_get_constraintdef(con.oid) ilike '%photo_scan%'
  loop
    execute format('alter table public.mistakes drop constraint %I', r.conname);
  end loop;
end
$mig$;

alter table public.mistakes
  add constraint mistakes_photo_scan_check
  check (photo_scan in ('pending', 'clear', 'flagged', 'unsupported'));

comment on column public.mistakes.photo_scan is
  'Fotoğrafın makine taraması: pending (taranmadı — paylaşılamaz), clear, '
  'flagged (şüpheli — paylaşılamaz, admin incelemesinde), unsupported '
  '(türü/boyutu taranamadı — paylaşılamaz, İHLAL DEĞİL, süpürücü kuyruğunda '
  'değil). Sahibin erişimini HİÇBİR değeri kısıtlamaz.';

-- ---------------------------------------------------------- kova sınırları
-- 0001 ve 0024 kovaları sınırsız kurmuştu; tek sınır config.toml'daki
-- proje geneli 50 MiB idi (üretimde geçerli bile değil).
--
-- 8 MiB, `analyze-question`ın MAX_BASE64 = 11_000_000 kapısıyla (~6 MB ham
-- görsel + base64 şişmesi) EŞDEĞER seçildi: analiz kabul ediyorsa tarama da
-- kabul edebilmeli, tersi de geçerli olmalı.
--
-- İstemci `image_picker`ı maxWidth 1600 / quality 85 ile çağırıyor ve
-- contentType'ı açıkça 'image/jpeg' yazıyor; bu sınırlar normal akışta
-- ısırmıyor, PostgREST'e doğrudan istek atan yolu kapatıyor.
update storage.buckets
   set file_size_limit    = 8 * 1024 * 1024,
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
 where id = 'mistake-photos';

update storage.buckets
   set file_size_limit    = 4 * 1024 * 1024,
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
 where id = 'avatars';

do $mig$
declare v_bad text[];
begin
  select array_agg(id order by id) into v_bad
    from storage.buckets
   where id in ('mistake-photos', 'avatars')
     and (file_size_limit is null or allowed_mime_types is null);
  if v_bad is not null then
    raise exception 'Kova sınırı yazılamadı: % — storage şeması beklenenden farklı', v_bad;
  end if;
end
$mig$;

-- --------------------------------------------- yönetici listesi tarama durumu
-- NEDEN: `admin_review_photo_scan(id, 'clear')` bir satırı DURUMUNA BAKMADAN
-- temiz yapıyor — yani yönetici hiç taranmamış (`pending`) ya da taranamamış
-- (`unsupported`) bir fotoğrafı da paylaşıma açabiliyor. Bu yetki bilerek
-- korunuyor (son söz insanda), ama KÖR olmamalı: liste artık durumu taşıyor,
-- arayüz de "taranmadı" / "taranamadı" rozetini gösteriyor.
--
-- Dönüş tipi değiştiği için `create or replace` yetmiyor; imza aynı kaldığı
-- için önce düşürülüyor (0014'ün aynı deseni).
drop function if exists public.admin_all_questions(int, int);
create or replace function public.admin_all_questions(
  p_limit  int default 200,
  p_offset int default 0
)
returns table (
  id             uuid,
  subject        text,
  concept        text,
  extra_concepts text[],
  exam           text,
  photo_path     text,
  options        jsonb,
  correct_index  int,
  is_public      bool,
  moderation     text,
  report_count   int,
  owner_nickname text,
  photo_scan     text,
  created_at     timestamptz
)
language sql stable security definer set search_path = public
as $fn$
  select m.id, m.subject, m.concept, m.extra_concepts, m.exam, m.photo_path,
         m.options, m.correct_index, m.is_public, m.moderation, m.report_count,
         p.nickname, m.photo_scan, m.created_at
    from public.mistakes m
    join public.profiles p on p.id = m.user_id
   where public.is_admin()
   order by m.created_at desc
   limit greatest(1, least(p_limit, 500))
  offset greatest(0, p_offset);
$fn$;

revoke execute on function public.admin_all_questions(int, int) from public, anon;
grant  execute on function public.admin_all_questions(int, int) to authenticated;
