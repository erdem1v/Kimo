-- test: supabase/tests/150_blocks_anonymous.sql
--
-- MUTASYON: `are_friends`ten engel kontrolunu sok (0008'deki haline dondur).
-- BEKLENEN: 150'nin "ENGELLI ciftte are_friends FALSE" ve "engelli eski
-- arkadasin avatar yolu profiles_public'te de null" iddialari kirmizi.
--
-- NEDEN BU BIR KORUMA: engelleme arkadasligi SILMIYOR. `are_friends` engelleri
-- gormezse "arkadas olmak" ile "engellenmis olmak" celismez ve engel kontrolu
-- HER sosyal yuzeyde AYRICA yazilmak zorunda kalir — unutuldugu yerlerde acik
-- kalir. Task 12 bu borcu bir mutasyonun icine yazmisti (mutations/42):
-- "`are_friends` engelleri HIC GORMUYOR ve ENGELLEME ARKADASLIGI SILMIYOR."
-- Bu mutasyon o cumleyi tekrar dogru hale getiriyor; test onu yakalamali.
--
-- NOT: iki govde de goc dosyasindan URETILDI. Kaynak: 0091.
create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $fn$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a))
  );
$fn$;
revoke execute on function public.are_friends(uuid, uuid) from public, anon;
grant execute on function public.are_friends(uuid, uuid) to authenticated;
-- @UNDO
create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $fn$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a))
  ) and not public.is_blocked_between(a, b);
$fn$;
revoke execute on function public.are_friends(uuid, uuid) from public, anon;
grant execute on function public.are_friends(uuid, uuid) to authenticated;
