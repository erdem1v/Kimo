-- 0057 — E-posta doğrulaması kaldırıldı: ölen dalın yorumu güncelleniyor
--
-- Task 06 kararı: e-posta doğrulaması tamamen kalkıyor. SMTP sağlayıcı
-- kurulmuyor (Supabase'in yerleşiği saatte 2 e-postayla sınırlı ve teslim
-- hızı doğrudan dönüşümü etkiliyor), karşılama akışındaki doğrulama adımı
-- silindi, `config.toml` → `enable_confirmations = false`.
--
-- BU GÖÇ KOD DEĞİŞTİRMİYOR, YALNIZCA YORUM. Değiştirdiği şey bir yalanı
-- kaldırmak: 0052 (`stale_anonymous_users`) "askıdaki e-posta dönüşümü olan
-- hesapları 30 güne kadar esirge" diye bir dal taşıyor ve gerekçesi
--
--     "kullanıcı 6. gün kayıt olur, sunucuda e-posta onayı AÇIK olduğu için
--      adres `email_change` alanında askıda kalır…"
--
-- diyor. Onay kapalıyken `auth.users.email_change` HİÇ dolmuyor: `updateUser`
-- anında tamamlanıyor, `email` yazılıyor ve `is_anonymous` düşüyor — yani
-- kullanıcı zaten bir sonraki koşuda aday listesine hiç girmiyor (fonksiyonun
-- `u.email is null` koşulu onu eliyor).
--
-- DALI SİLMİYORUZ. İki nedenle: (a) zararsız ve maliyetsiz — hiç tetiklenmeyen
-- bir `or` dalı; (b) doğrulama ileride geri gelirse veri kaybı koruması onunla
-- birlikte hazır duruyor. Silmek, geri açıldığı gün kimsenin hatırlamayacağı
-- sessiz bir veri kaybı yolu açardı. Yorum artık durumu doğru anlatıyor.
--
-- Geri alma: 0052'deki özgün yorumu geri yazmak yeterli; davranış aynı.

comment on function public.stale_anonymous_users(int) is
  'Süresi dolmuş anonim hesapların kimlikleri. Yalnızca servis rolü çağırır '
  '(cleanup-anonymous edge fonksiyonu). '
  'TASK 06: e-posta doğrulaması kaldırıldı (enable_confirmations = false), '
  'yani email_change hiç dolmuyor ve "askıdaki dönüşümü 30 güne kadar esirge" '
  'dalı artık HİÇ TETİKLENMİYOR — kayıt olan kullanıcı zaten u.email dolduğu '
  'için aday listesine girmiyor. Dal bilerek duruyor: doğrulama geri gelirse '
  'veri kaybı koruması da onunla geri gelsin.';
