import 'package:flutter/foundation.dart';

/// Reklam birimi kimlikleri — derleme zamanı, kaynağa gömülmüyor.
///
/// `SupabaseConfig` ve `LegalLinks` ile BİREBİR aynı desen: değerler
/// `--dart-define-from-file=supabase.json` ile geliyor.
///
/// **GOOGLE TEST KİMLİĞİ YEDEĞİ BİLİNÇLİ OLARAK YOK.** `SupabaseConfig`'in
/// kuralı burada da geçerli: yapılandırılmamış olmak "özellik yok" demek,
/// "sessizce test birimine düş" demek değil. Bir sürüm derlemesinin test
/// reklamı göstermesi, reklamın hiç gösterilmemesinden daha kötü — gelir
/// sıfır ama kullanıcı reklam görüyor.
///
/// Test kimlikleri `supabase.example.json`'da hazır duruyor; geliştirme
/// derlemesi onu kullanıyor, gerçek kimlikler yalnızca CI sırrında
/// (`SUPABASE_JSON`) ve yereldeki izlenmeyen `supabase.json`'da.
///
/// UYGULAMA KİMLİĞİ BURADA DEĞİL: `--dart-define` `AndroidManifest.xml`'e ve
/// `Info.plist`'e ulaşamıyor, AdMob SDK'sı ise uygulama kimliğini oradan
/// okuyor ve **eksikse uygulama açılışta ÇÖKÜYOR**. O yüzden iki dosyada da
/// Google'ın açık test uygulama kimliği duruyor ve sürümde Gradle
/// `manifestPlaceholders` / xcconfig ile geçersiz kılınıyor.
class AdsConfig {
  const AdsConfig._();

  static const String rewardedAndroid =
      String.fromEnvironment('ADMOB_REWARDED_ANDROID');

  static const String rewardedIos =
      String.fromEnvironment('ADMOB_REWARDED_IOS');

  /// Çalıştığı platformun ödüllü reklam birimi. Desteklenmeyen platformda boş.
  static String get rewardedUnitId {
    if (kIsWeb) return '';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => rewardedAndroid.trim(),
      TargetPlatform.iOS => rewardedIos.trim(),
      _ => '',
    };
  }

  /// Birim kimliği verilmemişse reklam yolu HİÇ çizilmiyor (sessizce).
  static bool get isConfigured => rewardedUnitId.isNotEmpty;

  /// AdMob TEST CİHAZI kimlikleri, virgülle ayrılmış.
  ///
  /// Yukarıdaki "test BİRİMİ yedeği yok" kuralıyla karıştırılmamalı — bu ondan
  /// farklı bir şey ve onun yarattığı boşluğu kapatıyor:
  ///
  ///   test BİRİMİ  = sahte reklam birimi kimliği (sürümde ASLA istemiyoruz)
  ///   test CİHAZI  = GERÇEK birim kimliğiyle, ama sahte reklam dolduran cihaz
  ///
  /// Gerçek birim kimlikleri girildiği anda, kayıtlı olmayan bir cihazda
  /// uygulamayı çalıştırmak CANLI reklam isteği demek ve Google bunu geçersiz
  /// trafik sayabiliyor. Test cihazı kaydı bunun tek meşru yolu.
  ///
  /// Cihaz kimliği uygulamayı bir kez çalıştırınca cihaz günlüğüne yazılıyor:
  ///   "Use RequestConfiguration.Builder.setTestDeviceIds(Arrays.asList(...))"
  ///
  /// Boş bırakılırsa hiçbir şey değişmez (üretim davranışı).
  static const String _testDeviceIdsRaw =
      String.fromEnvironment('ADMOB_TEST_DEVICE_IDS');

  static List<String> get testDeviceIds => _testDeviceIdsRaw
      .split(',')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toList(growable: false);
}
