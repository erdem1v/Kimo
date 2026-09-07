-- test: supabase/tests/040_moderation_storage.sql
--
-- MUTASYON: moderasyon kararını depolama katmanından çıkar; sahiplik ve
-- tarama kontrolleri kalır.
-- BEKLENEN: 040'ın "KALDIRILDI" iddiaları kırmızı.
create or replace function public.can_read_mistake_photo(p_name text)
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select public.is_admin() or exists (
    select 1 from public.mistakes m
    where m.photo_path = p_name
      and m.user_id::text = (storage.foldername(p_name))[1]
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
-- Kanonik sürüm (0050 — tarama şartlı) geri kurulur (bkz. 01'deki not).
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
