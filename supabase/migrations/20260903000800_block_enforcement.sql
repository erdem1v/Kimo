-- 0053b — Engel kontrolü RLS'in altından kaçıyordu (pgTAP süitinin İLK gerçek
-- koşusunda yakalandı — 150_blocks, test 7 ve 11).
--
-- SORUN: `user_blocks`'ı BİLEREK yalnız engelleyen görür (engellenen kişi
-- engellendiğini öğrenmemeli; blocks_select_own politikası ve 150'nin 8.
-- iddiası bu). Ama gönderim ve arkadaşlık-isteği politikaları engel
-- kontrolünü DÜZ alt sorguyla yapıyordu:
--
--   not exists (select 1 from public.user_blocks ...)
--
-- Politika ifadesindeki alt sorgu, İŞLEMİ YAPAN kullanıcının RLS'iyle
-- çalışır. Engellenen gönderici karşı tarafın engel satırını GÖREMEZ →
-- not exists hep TRUE → engellenen kişi engellendiği kişiye soru ve
-- arkadaşlık isteği göndermeye DEVAM EDEBİLİYORDU. Görünürlük gizliliği ile
-- zorlanabilirlik birbirini iptal etmişti; süit yazıldığından beri bu açığı
-- arıyordu ama hiç çalıştırılmamıştı.
--
-- ÇÖZÜM: `are_friends` ile aynı desen — RLS'i tanımlayıcı yetkisiyle aşan
-- küçük bir doğrulama fonksiyonu. Bilgi sızdırmaz: yalnızca boolean döner ve
-- politika içinde reddin nedeni zaten ayırt edilemez (42501).

create or replace function public.is_blocked_between(a uuid, b uuid)
returns boolean
language sql stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.user_blocks ub
     where (ub.blocker_id = a and ub.blocked_id = b)
        or (ub.blocker_id = b and ub.blocked_id = a)
  );
$$;

-- Politika ifadeleri ÇAĞIRANIN yetkisiyle değerlendirilir: açık kalmalı
-- (are_friends / can_read_mistake_photo ile aynı gerekçe).
revoke execute on function public.is_blocked_between(uuid, uuid)
  from public, anon;
grant  execute on function public.is_blocked_between(uuid, uuid)
  to authenticated;

-- ------------------------------------------------ gönderim politikası (v3)
-- 0050'deki metnin aynısı; yalnız engel kontrolü fonksiyona taşındı.
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
    and exists (
      select 1 from public.mistakes m
       where m.id = mistake_id
         and m.user_id = auth.uid()
         and m.moderation = 'ok'
         and m.photo_scan = 'clear'
    )
  );

-- ------------------------------------------- arkadaşlık isteği politikası
-- 0044'teki metnin aynısı; yalnız engel kontrolü fonksiyona taşındı.
drop policy if exists friendships_insert_own on public.friendships;
create policy friendships_insert_own on public.friendships
  for insert to authenticated
  with check (
    auth.uid() = requester_id
    and public.can_add_friends(auth.uid())
    and not public.is_blocked_between(requester_id, addressee_id)
  );
