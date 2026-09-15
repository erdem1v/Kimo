-- test: supabase/tests/050_avatars.sql
--
-- MUTASYON: `can_read_avatar`dan engel kontrolunu sok.
-- BEKLENEN: 050'nin "ENGELLEDIGI eski arkadasinin avatarini ARTIK okuyamiyor"
-- ve "ENGELLEDIGINDE kohort dali da kapaniyor" iddialari kirmizi.
--
-- NEDEN BU BIR KORUMA: bu fonksiyon `storage.objects` SELECT politikasinin TEK
-- kapisi, yani burasi bir DEPOLAMA erisimi — arayuz ayrintisi degil. Iki dal
-- birden aciktir: (a) ARKADAS dali, cunku engelleme arkadasligi SILMIYOR ve
-- `are_friends` engelleri hic gormuyor; (b) KOHORT dali, cunku engelledigin
-- kisiyle ayni lig grubunda olmak avatarina imzali URL uretmeye yetiyordu.
-- Arayuz metni ise fazlasini vaat ediyor (app_tr.arb:933 "listelerde seni
-- goremez").
--
-- NOT: iki govde de goc dosyasindan URETILDI. Kaynak: 0089.
create or replace function public.can_read_avatar(p_name text)
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select
    (storage.foldername(p_name))[1] = auth.uid()::text
    or exists (
      select 1
        from public.profiles p
       where p.avatar_path = p_name
         and (
           p.id = auth.uid()
           or public.are_friends(p.id, auth.uid())
           or exists (
             select 1
               from public.league_members m1
               join public.league_members m2
                 on m2.cohort_id = m1.cohort_id
              where m1.user_id = p.id
                and m2.user_id = auth.uid()
                and m1.week_start = public.istanbul_week()
           )
         )
    );
$fn$;
revoke execute on function public.can_read_avatar(text) from public, anon;
grant execute on function public.can_read_avatar(text) to authenticated;
-- @UNDO
create or replace function public.can_read_avatar(p_name text)
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select
    (storage.foldername(p_name))[1] = auth.uid()::text
    or exists (
      select 1
        from public.profiles p
       where p.avatar_path = p_name
         and (
           p.id = auth.uid()
           or public.are_friends(p.id, auth.uid())
           or exists (
             select 1
               from public.league_members m1
               join public.league_members m2
                 on m2.cohort_id = m1.cohort_id
              where m1.user_id = p.id
                and m2.user_id = auth.uid()
                and m1.week_start = public.istanbul_week()
           )
         )
         and not public.is_blocked_between(p.id, auth.uid())
    );
$fn$;
revoke execute on function public.can_read_avatar(text) from public, anon;
grant execute on function public.can_read_avatar(text) to authenticated;
