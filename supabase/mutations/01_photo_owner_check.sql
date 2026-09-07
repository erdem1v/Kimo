-- test: supabase/tests/030_photo_ownership.sql
--
-- MUTASYON: can_read_mistake_photo'dan YALNIZCA sahiplik kontrolünü çıkar
-- (moderation ve tarama kontrolleri yerinde kalır — onları 03 ve 09 sınıyor).
-- Böylece fonksiyon yine "bu yolu talep eden bir satır var mı?" sorusuna
-- dönüyor.
--
-- BEKLENEN: 030'daki SAHTECİLİK iddiaları kırmızı.
create or replace function public.can_read_mistake_photo(p_name text)
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select public.is_admin() or exists (
    select 1 from public.mistakes m
    where m.photo_path = p_name
      and m.moderation <> 'removed'
      and (
        m.user_id = auth.uid()
        or (m.is_public       and m.photo_scan = 'clear')
        or (m.photo_scan = 'clear' and exists (
          select 1 from public.question_sends s
          where s.mistake_id = m.id and s.receiver_id = auth.uid()
        ))
      )
  );
$fn$;
-- @UNDO
-- Kanonik sürüm (0050 — tarama şartlı) geri kurulur. Eskiden buradaki geri
-- alma tarama-öncesi metni kuruyordu ve sonraki mutasyonların 1. fazında
-- 220_photo_scan bozuk fikstürle kırmızı görünüyordu.
create or replace function public.can_read_mistake_photo(p_name text)
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select public.is_admin() or exists (
    select 1
    from public.mistakes m
    where m.photo_path = p_name
      and m.user_id::text = (storage.foldername(p_name))[1]
      and m.moderation <> 'removed'
      and (
        m.user_id = auth.uid()
        or (m.is_public       and m.photo_scan = 'clear')
        or (m.photo_scan = 'clear' and exists (
          select 1 from public.question_sends s
          where s.mistake_id = m.id and s.receiver_id = auth.uid()
        ))
      )
  );
$fn$;
