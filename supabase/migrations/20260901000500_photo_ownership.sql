-- 0030 — Fotoğraf yetkisi dosyanın SAHİPLİĞİNDEN türer (H4 + Değişmez 2 ve 3)
--
-- SORUN (H4): can_read_mistake_photo şu soruyu soruyordu:
--     "bu yolu talep eden herhangi bir satır var mı?"
-- Doğru soru şuydu:
--     "bu satır bu dosyanın sahibi mi?"
-- photo_path serbest metin ve insert politikası yalnızca auth.uid() = user_id
-- kontrolü yaptığı için saldırgan kendi satırına BAŞKASININ yolunu yazabiliyordu:
--
--     insert into mistakes (subject, concept, mistake_type, photo_path, is_public)
--     values ('X','Y','dikkatsizlik','<kurban-uid>/1699999999.jpg', true);
--
-- Bu satır iki dalı birden açıyordu: m.user_id = auth.uid() (saldırgan okur) ve
-- m.is_public (HERKES okur — yani kurbanın özel fotoğrafı havuzda yayınlanır).
--
-- NÜANS, dürüstlük payı: yol <uid>/<epoch_ms>.jpg ve epoch_ms tahmin edilebilir
-- değil. Yani bu körlemesine rastgele dosya okuma değil; bir kez MEŞRU olarak
-- gördüğün yolu (havuz, sana gönderilen soru, moderasyon kuyruğu) kalıcılaştırma
-- ve iptali atlatma primitifi. Sahibi paylaşımı geri çekse ya da moderatör
-- kaldırsa bile erişim sürüyordu.
--
-- ÇÖZÜM iki bağımsız katman:
--   (1) VERİ: CHECK kısıtı — bir satır kendi sahibinin klasörü dışını gösteremez.
--       Gölge satır artık kurulamıyor. Kısıt her role uygulanır (service_role
--       dahil); içe aktarıcının <ownerId>/<source>/<dosya> şeması uyumlu, ilk
--       segment yine sahibin kimliği.
--   (2) YETKİ: erişim veren satır dosyanın sahibi OLMAK ZORUNDA + moderasyon
--       kararı depolama katmanında da geçerli.
--
-- VERİ GÖÇÜ YOK: canlıda gerçek müşteri verisi olmadığı teyit edildi, kısıtlar
-- doğrudan `valid` kuruluyor.

-- ================================================================ (1) VERİ
alter table public.mistakes
  drop constraint if exists mistakes_photo_path_owned;
alter table public.mistakes
  add constraint mistakes_photo_path_owned
  check (photo_path is null or photo_path like user_id::text || '/%');

comment on constraint mistakes_photo_path_owned on public.mistakes is
  'Fotoğraf yolu satırın sahibinin klasöründe olmak zorunda; gölge satırla '
  'başkasının dosyasını talep etmeyi imkânsız kılar (H4).';

-- Avatar için aynı kalıp.
-- NOT: bunu profiles UPDATE politikasına `with check` olarak EKLEMİYORUM.
-- Postgres'te WITH CHECK'i olmayan bir UPDATE politikasında USING ifadesi yeni
-- satır için de uygulanır; `with check` eklediğim anda o örtük koruma kaybolur
-- ve `auth.uid() = id`'yi elle yeniden yazmam gerekirdi. CHECK kısıtı aynı
-- garantiyi daha güçlü veriyor (her role uygulanıyor) ve o tuzağa hiç girmiyor.
alter table public.profiles
  drop constraint if exists profiles_avatar_path_owned;
alter table public.profiles
  add constraint profiles_avatar_path_owned
  check (avatar_path is null or avatar_path like id::text || '/%');

-- ================================================================ (2) YETKİ
-- Kilit taşı: m.user_id::text = (storage.foldername(p_name))[1]
-- Erişim veren satır dosyanın sahibi olmak zorunda. CHECK kısıtı bunu zaten
-- garanti ediyor, ama fonksiyon da bağımsız olarak doğruluyor: biri atlanırsa
-- diğeri tutar.
--
-- Ve `m.moderation <> 'removed'`: moderasyon kararı artık depolama katmanında
-- da geçerli (Değişmez 3). Yönetici dalı ayrı — moderatör incelemek için
-- kaldırılmış içeriği de görebilmeli.
create or replace function public.can_read_mistake_photo(p_name text)
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select public.is_admin() or exists (
    select 1
    from public.mistakes m
    where m.photo_path = p_name
      -- Erişim veren satır dosyanın SAHİBİ mi? (H4'ün çekirdeği)
      and m.user_id::text = (storage.foldername(p_name))[1]
      -- Kaldırılan içerik depolama katmanında da kapalı (Değişmez 3)
      and m.moderation <> 'removed'
      and (
        m.user_id = auth.uid()                       -- kendi fotoğrafın
        or m.is_public                               -- havuza açılmış soru
        or exists (                                  -- sana gönderilmiş soru
          select 1 from public.question_sends s
          where s.mistake_id = m.id and s.receiver_id = auth.uid()
        )
      )
  );
$fn$;

-- ------------------------------------------------------ tek okuma otoritesi
-- init göçündeki "Kendi fotolarını gör" AYRI bir permissive SELECT politikasıydı
-- ve çoklu permissive politikalar OR'lanır. Yani sahibi, can_read_mistake_photo
-- ne derse desin kendi klasöründeki HER ŞEYİ okuyabiliyordu — kaldırılmış içerik
-- dahil. Değişmez 3 bu politika dururken sağlanamaz.
--
-- Kaldırılıyor: can_read_mistake_photo sahibi zaten kapsıyor (kendi satırı
-- üzerinden). Kaybedilen tek şey, karşılığında `mistakes` satırı OLMAYAN yetim
-- bir nesneyi okuyabilmek — ki onu zaten istemiyoruz.
--
-- Yükleme ve kendi dosyanı silme politikaları (init) DOKUNULMADAN kalıyor:
-- yükleme akışı ve kullanıcının kendi verisini silmesi (KVKK Md. 7) için şart.
drop policy if exists "Kendi fotolarını gör" on storage.objects;

drop policy if exists "mistake photos readable" on storage.objects;
create policy "mistake photos readable" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'mistake-photos'
    and public.can_read_mistake_photo(name)
  );
