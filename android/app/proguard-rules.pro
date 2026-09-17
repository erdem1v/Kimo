# R8/ProGuard kuralları (Task 03 — küçültme/karartma açıldı).
#
# Dart kodu AOT derlendiği için R8'den etkilenmez; buradaki kurallar yalnızca
# Kotlin/Java eklenti yüzeyini korur. Kural eklerken nedenini yaz: nedensiz
# -keep, karartmanın sağladığı yüzey daralmasını sessizce geri açar.

# --- flutter_local_notifications -------------------------------------------
# Planlanmış bildirimler Gson ile diske serileştiriliyor; R8 alan adlarını
# karartırsa cihaz yeniden başladığında bildirimler çözülemez (klasik kırılma).
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
-keepattributes *Annotation*

# --- Flutter gömme katmanı --------------------------------------------------
# Eklenti kayıt mekanizması yansımayla sınıf adı arıyor.
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# Firebase/Play Services kendi consumer kurallarını taşır; ek kural gerekmedi.
# Bir eklenti güncellemesi release'te ClassNotFound/AbstractMethodError
# üretirse önce o eklentinin consumer kurallarının gelip gelmediğine bakın.

# --- Play Core (ertelenmiş bileşenler) --------------------------------------
# Flutter'ın gömme katmanı `FlutterPlayStoreSplitApplication` sınıfını
# taşıyor ve o da Play Core'un `SplitCompatApplication`ını referans veriyor.
# ERTELENMİŞ BİLEŞEN KULLANMIYORUZ: uygulama tek modül, `--split-debug-info`
# ya da deferred component yok. Bağımlılığı eklemek kullanılmayan bir kütüphaneyi
# pakete sokardı; doğru cevap R8'e "bu sınıfların yokluğu beklenen" demek.
#
# NEDEN ŞİMDİ GÖRÜLDÜ: Android tarafı bu depoda HİÇ derlenmemişti (geliştirme
# makinesinde SDK yok, CI'da da iş yoktu). R8 yalnızca `--release`te çalışıyor
# ve `Missing classes detected` hatasını HATAYA yükseltiyor — yani
# `flutter build appbundle --release`, yani PLAY'E YÜKLENECEK YAPI, kırıktı.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication
