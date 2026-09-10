-- test: supabase/tests/240_persona.sql
--
-- MUTASYON: anti-tekrar imlecini uygulamaya aç.
-- BEKLENEN: 240'ın "authenticated push_cursors okuyamaz" ve davranışsal
-- 42501 iddiaları kırmızı.
--
-- Neden önemli: imleç yazılabilir olsaydı kullanıcı hangi cümlenin sırada
-- olduğunu seçebilirdi; okunabilir olsaydı başkalarının bildirim geçmişi
-- sızardı (satırlar user_id kırılımlı ve RLS politikası YOK).
grant select, update on public.push_cursors to authenticated;
-- @UNDO
revoke all on public.push_cursors from public, anon, authenticated;
