-- test: supabase/tests/270_sanctions.sql
--
-- MUTASYON: `mistakes` INSERT politikasını YAŞ koşuluyla ama ASKI koşulu
-- OLMADAN yeniden yaz.
-- BEKLENEN: 270'in "ASKIDAN SONRA: aynı hata kaydı REDDEDİLİYOR" ve
-- "INSERT politikası HEM askı HEM yaş koşulunu taşıyor" iddiaları kırmızı.
--
-- Neden bu mutasyon "doğru görünen yanlış": 0067 bu politikaya yaş koşulu
-- ekledi. Politika `drop` + `create` ile YENİDEN YAZILIYOR, yani 0062'nin
-- askı koşulunu elle taşımak gerekiyordu. Onu düşürmek bu paketin en olası
-- regresyonu ve dışarıdan bakınca göç doğru görünüyor: yaş kapısı çalışıyor,
-- 130 yeşil, hiçbir şey patlamıyor. Kırmızıya dönmesi gereken 270.
--
-- Yani bu dosya iki testin AYNI ŞEYİ ölçmediğini kanıtlıyor: yaş kapısını
-- sınayan test, askı korumasının hâlâ orada olduğuna dair hiçbir şey söylemez.
drop policy if exists "Kendi hatanı ekle" on public.mistakes;
create policy "Kendi hatanı ekle"
  on public.mistakes for insert
  with check (
    auth.uid() = user_id
    and public.has_birth_year(auth.uid())
  );

-- @UNDO
drop policy if exists "Kendi hatanı ekle" on public.mistakes;
create policy "Kendi hatanı ekle"
  on public.mistakes for insert
  with check (
    auth.uid() = user_id
    and not public.is_suspended(auth.uid())
    and public.has_birth_year(auth.uid())
  );
