-- test: supabase/tests/070_push_lines_rls.sql
--
-- MUTASYON: push_lines'ı RLS'siz ve okunabilir hâle döndür.
-- BEKLENEN: 070'in RLS ve grant iddiaları kırmızı.
alter table public.push_lines disable row level security;
grant select, insert, update, delete on public.push_lines to authenticated;
-- @UNDO
alter table public.push_lines enable row level security;
revoke all on public.push_lines from public, anon, authenticated;
