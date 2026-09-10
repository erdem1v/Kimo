-- test: supabase/tests/020_mistakes_column_lockdown.sql
--
-- MUTASYON: istemciye `mistakes` üzerinde DELETE yetkisini geri ver
-- (0069 öncesine dön).
-- BEKLENEN: 020'nin "istemci mistakes satırı SİLEMEZ" iddiaları kırmızı.
--
-- Neden bu mutasyon: silme İKİ nesneye dokunuyor — satır ve depodaki dosya.
-- İstemci satırı silerse `photo_path` kaybolur ve fotoğraf nesne deposunda
-- YETİM kalır. Kullanıcı "sildim" görür, dosya durur. "Kaldırıldı gerçekten
-- kaldırır" değişmezi (Task 01) tam burada sessizce yalan olur; hiçbir hata,
-- hiçbir günlük satırı üretmeden.
grant delete on public.mistakes to authenticated;

-- @UNDO
revoke delete on public.mistakes from public, anon, authenticated;
