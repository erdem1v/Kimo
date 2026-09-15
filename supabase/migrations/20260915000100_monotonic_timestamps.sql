-- 0095 — Aynı işlemde yazılan satırların sırası artık belirli (Task 14 · G4)
--
-- BULGU: `is_suspended` "en yeni yaptırım kazanır" mantığını
--   order by s.created_at desc, s.id desc limit 1
-- ile kuruyor. `created_at` varsayılanı `now()` — yani İŞLEM zamanı, satır
-- zamanı değil. Aynı işlemde yazılan iki yaptırım EŞİT damga taşıyor ve
-- `id` rastgele bir uuid (`gen_random_uuid()`) olduğu için ikinci anahtar
-- sıralamayı belirli hâle GETİRMİYOR: "en yenisi" rastgele seçiliyor.
--
-- ÜRETİMDE NASIL OLUR: tek bir
--   update public.mistakes set photo_scan = 'flagged' where ...
-- ifadesi birden çok satıra dokunabilir; tetikleyici her biri için bir ihlal
-- yazar ve eşik dolduğunda yaptırım üretir. Hepsi AYNI işlemde. O anda
-- kullanıcının askılı mı yasaklı mı olduğu rastgele belirlenir — aynı
-- belirsizlik kullanıcının kendi durum ekranını (`my_sanction`) ve
-- yöneticinin gördüğü listeyi (`admin_user_sanctions`) de vuruyor.
--
-- KANIT: pgTAP 270'in aynı desendeki iddiası CI'ın 3. turunda tesadüfen
-- yeşil, 4. turunda kırmızı döndü. Test kendi başına güvenilmezdi.
--
-- ÇÖZÜM: varsayılan `clock_timestamp()`. İşlem boyunca İLERLEYEN saat, yani
-- aynı işlemdeki her satır farklı damga alıyor ve `created_at desc` tek
-- başına belirli hâle geliyor.
--
-- NEDEN YENİ BİR SIRA SÜTUNU DEĞİL: `bigserial` bir sütun eklemek doğru
-- sıralamayı verirdi ama `user_sanctions` lockdown sınıflandırma listelerinde
-- yer alıyor ve tablonun kendi yorumu "yeni kolon eklerseniz YENİ bir lockdown
-- göçü yazın" diyor — üç tablo için üç sütun, yeni bir lockdown turu ve
-- recheck zinciri demekti. Varsayılanı değiştirmek aynı değişmezi tek satırla
-- kuruyor ve şema yüzeyine hiç dokunmuyor.
--
-- `clock_timestamp()` ANLAMCA DA DAHA DOĞRU: kayıt anı, işlemin başladığı an
-- değil satırın yazıldığı an. Mevcut satırlara dokunulmuyor.

alter table public.user_sanctions
  alter column created_at set default clock_timestamp();

-- Aynı kusur, aynı sebep: ihlal defterini `strike_no` kurtarıyordu ama
-- `created_at` sıralaması yine berabere kalıyordu.
alter table public.photo_violations
  alter column created_at set default clock_timestamp();

-- `my_consents` görünümü `distinct on (kind) ... order by kind, recorded_at
-- desc` ile en güncel onayı seçiyor. Aynı işlemde iki onay yazıldığında hangi
-- SÜRÜMÜN onaylandığı rastgele dönüyordu — onay kaydının ispat değeri tam da
-- sürümünde.
alter table public.user_consents
  alter column recorded_at set default clock_timestamp();

comment on column public.user_sanctions.created_at is
  'Kararın yazıldığı an. `clock_timestamp()` (0095): `now()` işlem zamanı '
  'olduğu için aynı işlemde yazılan yaptırımlar eşit damga taşıyor ve '
  '"en yenisi kazanır" sıralaması rastgeleye düşüyordu.';
