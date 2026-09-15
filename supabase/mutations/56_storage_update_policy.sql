-- test: supabase/tests/030_photo_ownership.sql
--
-- MUTASYON: `storage.objects` uzerine bir UPDATE politikasi ekle.
--
-- BEKLENEN: 030'un "storage.objects uzerinde UPDATE politikasi YOK" iddiasi
-- kirmizi.
--
-- NEDEN BU BIR KORUMA: Task 14'te istemcinin `upsert: true` ile yukledigi her
-- fotograf 403 ile dusuyordu, cunku Supabase Storage upsert'i sunucuda UPSERT
-- olarak isliyor ve UPDATE politikasi ariyor. O hatanin KOLAY ama YANLIS
-- duzeltmesi buraya bir UPDATE politikasi eklemekti: o politika, taramasi
-- 'clear' cikmis bir fotografin uzerine baska bir gorsel yazilmasina izin
-- verir ve `mistakes.photo_path`in yaz-bir-kez olmasini (0020
-- `revoke update (photo_path)`) anlamsiz kilardi. Dogru duzeltme istemciden
-- `upsert`i kaldirmakti; bu mutasyon yanlis yola karsi olan kapiyi siniyor.
create policy "__mut_storage_update"
  on storage.objects for update to authenticated
  using (bucket_id = 'mistake-photos'
         and (storage.foldername(name))[1] = auth.uid()::text);

-- @UNDO
drop policy if exists "__mut_storage_update" on storage.objects;
