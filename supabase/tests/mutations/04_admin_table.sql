-- test: supabase/tests/095_admins.sql
--
-- MUTASYON: admins tablosunu uygulama rolüne aç (C1'i geri getir).
-- BEKLENEN: 095'in "sıradan kullanıcı kendini yönetici yapamaz" iddiası kırmızı.
grant select, insert on public.admins to authenticated;
-- @UNDO
revoke all on public.admins from public, anon, authenticated;
