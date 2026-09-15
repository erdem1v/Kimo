-- test: supabase/tests/270_sanctions.sql
--
-- MUTASYON: askı kontrolünü hata kaydı ve gönderim politikalarından çıkar
-- (0062 öncesindeki metinler).
-- BEKLENEN: 270'in "ASKIDAN SONRA ... REDDEDİLİYOR" iddiaları kırmızı.
--
-- Neden bu mutasyon: yasağın istemci kapısıyla da "çalışıyor" görünmesi çok
-- kolay. Bu mutasyon, iddianın gerçekten VERİ KATMANINI ölçtüğünü kanıtlıyor:
-- politika metninden tek bir koşul çıkınca PostgREST'e doğrudan istek atan
-- askılı kullanıcı yine içerik üretebiliyor.
drop policy if exists "Kendi hatanı ekle" on public.mistakes;
create policy "Kendi hatanı ekle"
  on public.mistakes for insert
  with check (auth.uid() = user_id);

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
-- @UNDO
-- CANLI politika 0067'nin sürümü. Bu geri alma 0062'yi kuruyordu ve
-- `and public.has_birth_year(auth.uid())` koşulunu TAŞIMIYORDU: mutasyon 19
-- koştuktan sonra koşunun geri kalanında YAŞ KAPISI politikadan düşüyordu.
-- 270'in "INSERT politikası HEM askı HEM yaş koşulunu taşıyor" iddiası FAZ
-- 3'te bu yüzden yeşile dönmüyordu.
drop policy if exists "Kendi hatanı ekle" on public.mistakes;
create policy "Kendi hatanı ekle"
  on public.mistakes for insert
  with check (
    auth.uid() = user_id
    and not public.is_suspended(auth.uid())
    and public.has_birth_year(auth.uid())
  );

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
