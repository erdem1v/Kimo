-- test: supabase/tests/220_photo_scan.sql
--
-- MUTASYON: can_read_mistake_photo'dan tarama şartını çıkar (0050 öncesine
-- dön: paylaşım dalları photo_scan'e bakmasın).
-- BEKLENEN: 220'nin "pending fotoğrafı BAŞKASI okuyamaz" iddiası kırmızı.
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
        or m.is_public
        or exists (
          select 1 from public.question_sends s
          where s.mistake_id = m.id and s.receiver_id = auth.uid()
        )
      )
  );
$fn$;
-- @UNDO
-- Tarama şartlı sürümü (0050) geri kur.
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
