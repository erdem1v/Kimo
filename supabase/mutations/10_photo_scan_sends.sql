-- test: supabase/tests/220_photo_scan.sql
--
-- MUTASYON: gönderim politikasından tarama şartını çıkar (0050 öncesi hâline
-- döndür — taranmamış fotoğraf arkadaşa gidebilsin).
-- BEKLENEN: 220'nin "pending fotoğraflı soru arkadaşa GÖNDERİLEMEZ" iddiası
-- kırmızı.
drop policy if exists sends_insert_friend on public.question_sends;
create policy sends_insert_friend on public.question_sends
  for insert to authenticated
  with check (
    auth.uid() = sender_id
    and not exists (
      select 1 from public.profiles p
       where p.id = auth.uid() and p.is_anonymous
    )
    and public.are_friends(sender_id, receiver_id)
    and not public.is_blocked_between(sender_id, receiver_id)
  );
-- @UNDO
-- CANLI politikayı (0062) geri kur — 0053b'yi DEĞİL.
--
-- BU GERİ ALMA BAYATTI ve sessizce bir korumayı düşürüyordu: 0053b sürümünde
-- `not public.is_suspended(auth.uid())` YOK. 0062 onu ekledi. Geri alma eski
-- metni kurduğu için, mutasyon 10 koştuktan SONRA askı koşulu politikadan
-- kalkıyor ve koşunun geri kalanında askıdaki kullanıcı soru gönderebiliyordu.
-- Sonucu 270'in "ASKIDAN SONRA: soru gönderemiyor" iddiasının FAZ 1'de
-- kırmızı düşmesiydi (mutasyon 18/19/20/27 "zaten kırmızı" diye raporlandı).
drop policy if exists sends_insert_friend on public.question_sends;
create policy sends_insert_friend on public.question_sends
  for insert to authenticated
  with check (
    auth.uid() = sender_id
    and not public.is_suspended(auth.uid())
    and not exists (
      select 1 from public.profiles p
       where p.id = auth.uid() and p.is_anonymous
    )
    and public.are_friends(sender_id, receiver_id)
    and not public.is_blocked_between(sender_id, receiver_id)
    and exists (
      select 1 from public.mistakes m
       where m.id = mistake_id
         and m.user_id = auth.uid()
         and m.moderation = 'ok'
         and m.photo_scan = 'clear'
    )
  );
