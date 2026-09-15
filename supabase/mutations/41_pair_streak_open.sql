-- test: supabase/tests/320_pair_streaks.sql
--
-- MUTASYON: devir fonksiyonunu istemciye aç.
-- BEKLENEN: 320'nin "devir fonksiyonu KAPALI — kullanıcı seriyi elle
-- ilerletemez" iddiası kırmızı.
--
-- NEDEN BU BİR KORUMA: `pair_streak_rollover()` bütün ikili serileri
-- ilerletiyor ve tarih karşılaştırmasıyla çalışıyor. İstemciye açıksa kullanıcı
-- onu tekrar tekrar çağırıp KENDİ serisini (ve herkesin serisini) şişirebilir.
-- Ortak serinin tek anlamı "iki kişi gerçekten çalıştı"; elle ilerletilebilen
-- bir sayı o anlamı tümden kaybeder.
grant execute on function public.pair_streak_rollover() to authenticated;
-- @UNDO
revoke execute on function public.pair_streak_rollover()
  from public, anon, authenticated;
