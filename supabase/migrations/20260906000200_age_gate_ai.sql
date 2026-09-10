-- 0067 — Yaş kapısı analizin VE depolamanın önüne geçiyor (A-2)
--
-- SORUN (Task 07 raporu §6, en kırılgan bayrak): onboarding sırası
-- `firstCapture → age → …`. Öğrencinin ilk fotoğrafı, yaşı bilinmeden
-- OpenAI'a gidiyordu. 0063 ile 13 yaş sınırını zorlamaya başladık ve hukuki
-- metinler "13 altını kabul etmiyoruz" diyor — yani reddedeceğimiz bir
-- kullanıcının verisini reddetmeden ÖNCE yurt dışına aktarıyorduk.
--
-- İSTEMCİ TARAFI erteleme tek başına yeterli değil: PostgREST'e ya da edge
-- fonksiyonuna doğrudan istek atan biri arayüzü hiç görmez. Bu göç kapıyı
-- VERİ KATMANINA koyuyor.
--
-- NEDEN "doğum yılı dolu" testi yaşı hesaplamaya yetiyor: `set_birth_year`
-- (0063) TEK YAZIMLIK ve 13 altını `KM013` ile reddediyor. Yani sütun
-- doluysa değeri mutlaka 13+ bir yıl. Yaşı burada yeniden hesaplamak aynı
-- kuralın ikinci bir kopyasını yaratırdı; ayrışırlarsa hangisinin doğru
-- olduğu belirsizleşir.

-- ------------------------------------------------------------- yardımcılar
-- POLİTİKA İÇİNDEN çağrılıyor → `security definer` VE `authenticated`'a açık
-- olmak ZORUNDA (0052'nin dersi, `is_suspended` ile aynı gerekçe: politika
-- ifadesi ÇAĞIRANIN yetkisiyle değerlendirilir; `profiles` satırı RLS ile
-- süzülseydi alt sorgu boş döner ve kapı hiç ısırmazdı).
create or replace function public.has_birth_year(p_user uuid)
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select exists (
    select 1 from public.profiles p
     where p.id = p_user and p.birth_year is not null
  );
$fn$;

revoke execute on function public.has_birth_year(uuid) from public, anon;
grant  execute on function public.has_birth_year(uuid) to authenticated;

comment on function public.has_birth_year(uuid) is
  'Doğum yılı yazılmış mı. set_birth_year tek yazımlık ve 13 altını KM013 ile '
  'reddettiği için "dolu" ⟹ "13 yaş ve üzeri". Yaşın KENDİSİNİ döndürmez.';

-- Edge fonksiyonunun (analyze-question) çağırdığı kapı. Parametresizdir:
-- kimin sorulduğuna istemci karar veremez.
create or replace function public.ai_age_ok()
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select public.has_birth_year(auth.uid());
$fn$;

revoke execute on function public.ai_age_ok() from public, anon;
grant  execute on function public.ai_age_ok() to authenticated;

comment on function public.ai_age_ok() is
  'analyze-question bunu OpenAI çağrısından, önbellekten ve kotadan ÖNCE '
  'sorar. false ise fotoğraf hiçbir yere gitmez.';

-- ================================================== yaş kapısı yazma yollarında
-- DİKKAT — İKİ KOŞUL BİRLİKTE: aşağıdaki iki politika 0062'de yaptırım için
-- yazılmıştı ve `not public.is_suspended(auth.uid())` taşıyorlar. Yaş koşulu
-- EKLENİYOR, askı koşulu KORUNUYOR. Bu paketin en olası regresyonu askı
-- koşulunu yeniden yazarken düşürmek; `supabase/mutations/27_age_gate_drops_
-- suspension.sql` tam olarak o senaryoyu kurup 270'in kırmızıya döndüğünü
-- kanıtlıyor.

-- 1) Hata satırı (fotoğrafın yolu da buradan geliyor).
drop policy if exists "Kendi hatanı ekle" on public.mistakes;
create policy "Kendi hatanı ekle"
  on public.mistakes for insert
  with check (
    auth.uid() = user_id
    and not public.is_suspended(auth.uid())
    and public.has_birth_year(auth.uid())
  );

-- 2) Depolama nesnesi. Satır ve nesne AYRI yollar: yalnızca birini kapatmak
--    diğerini açık bırakırdı (0031 ve 0062'nin aynı gerekçesi). "13 altı
--    reddedilirse o fotoğraf depolamada bırakılmamalı" ancak ikisi birden
--    kapalıyken doğru.
drop policy if exists "Kendi fotolarını yükle" on storage.objects;
create policy "Kendi fotolarını yükle"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'mistake-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and not public.is_suspended(auth.uid())
    and public.has_birth_year(auth.uid())
  );

-- DEĞİŞMEYEN, BİLİNÇLİ: `question_sends` ve `friendships` INSERT politikaları
-- (0062'nin 3. ve 4. yolu) yaş koşulu ALMIYOR. Yaş kapısının konusu yurt dışına
-- veri aktarımı ve fotoğraf saklama; arkadaşlık 0063'te yaştan bağımsız hâle
-- getirildi ve o kararı burada geri almıyoruz.
--
-- Okuma yolları da değişmiyor: doğum yılı olmayan bir kullanıcı kendi eski
-- verisini okumaya devam eder (KVKK Md. 11).
