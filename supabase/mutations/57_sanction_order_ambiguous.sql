-- test: supabase/tests/270_sanctions.sql
--
-- MUTASYON: `user_sanctions.created_at` varsayilanini `now()`a geri dondur.
--
-- BEKLENEN: 270'in "ayni islemde yazilan uc yaptirim UC FARKLI damga tasiyor"
-- iddiasi kirmizi.
--
-- NEDEN BU BIR KORUMA: `now()` ISLEM zamanidir, satir zamani degil. Ayni
-- islemde yazilan yaptirimlar esit damga tasiyor ve `is_suspended`in
-- `order by created_at desc, id desc` siralamasinin ikinci anahtari rastgele
-- bir uuid — yani "en yeni yaptirim kazanir" kurali rastgeleye dusuyor.
-- Uretimde tek bir `update ... set photo_scan = 'flagged'` ifadesi birden cok
-- ihlali ayni islemde tetikleyebiliyor; o anda kullanicinin askili mi yasakli
-- mi oldugu sansa kaliyordu (Task 14 · G4).
alter table public.user_sanctions
  alter column created_at set default now();

-- @UNDO
alter table public.user_sanctions
  alter column created_at set default clock_timestamp();
