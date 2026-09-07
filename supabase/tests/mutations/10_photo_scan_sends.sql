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
    and not exists (
      select 1 from public.user_blocks b
       where (b.blocker_id = receiver_id and b.blocked_id = sender_id)
          or (b.blocker_id = sender_id   and b.blocked_id = receiver_id)
    )
  );
-- @UNDO
-- Tarama şartlı politikayı (0050) geri kur.
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
    and not exists (
      select 1 from public.user_blocks b
       where (b.blocker_id = receiver_id and b.blocked_id = sender_id)
          or (b.blocker_id = sender_id   and b.blocked_id = receiver_id)
    )
    and exists (
      select 1 from public.mistakes m
       where m.id = mistake_id
         and m.user_id = auth.uid()
         and m.moderation = 'ok'
         and m.photo_scan = 'clear'
    )
  );
