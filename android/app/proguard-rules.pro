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
