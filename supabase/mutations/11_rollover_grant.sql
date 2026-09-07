-- test: supabase/tests/098_function_grants.sql
--
-- MUTASYON: haftalık lig yerleşimini kullanıcıya aç.
-- BEKLENEN: 098'in "league_weekly_rollover KAPALI" iddiası kırmızı — açık
-- kalsaydı herkes yerleşimi (ve settle'ı) istediği an tetikleyebilirdi.
grant execute on function public.league_weekly_rollover() to authenticated;
-- @UNDO
revoke execute on function public.league_weekly_rollover()
  from public, anon, authenticated;
