import 'package:flutter/foundation.dart';

import 'ad_service_stub.dart'
    if (dart.library.io) 'ad_service_mobile.dart';

/// Bir ödüllü reklam gösteriminin sonucu.
///
/// DİKKAT: [earned] "hak kazandı" DEMEK DEĞİL. Yalnızca AdMob SDK'sının
/// "kullanıcı ödülü hak etti" dediği anlamına geliyor ve o iddia İSTEMCİDEN
/// geliyor, yani kanıt değil. Hakkı Google'ın sunucu tarafı doğrulama geri
/// çağrısı veriyor (`supabase/functions/ad-reward`); istemci bunu ancak
/// `my_daily_state`i yeniden okuyarak görebiliyor.
enum AdOutcome {
  /// SDK ödülü bildirdi. Kanıt değil — sunucu doğrulaması beklenmeli.
  earned,

  /// Kullanıcı reklamı erken kapattı. Sessizce geçiliyor.
  dismissed,

  /// Gösterilecek reklam yok (doluluk, yapılandırma, desteklenmeyen platform).
  notReady,

  /// SDK hata verdi. Kullanıcıya GÖSTERİLMİYOR, yalnızca raporlanıyor.
  failed,
}

/// Ödüllü reklam servisi.
///
/// TEK REKLAM BİÇİMİ: ödüllü. Interstitial, banner ve açılış reklamı yok ve
/// eklenmeyecek — kullanıcı isteyerek izliyor, karşılığında hak kazanıyor.
///
/// UYGULAMA SEÇİMİ KOŞULLU IMPORT'LA: `ad_service_stub.dart` (web, masaüstü,
/// testler) ya da `ad_service_mobile.dart` (yalnızca bu dosya
/// `google_mobile_ads`'i import ediyor).
///
/// KOŞULLU IMPORT TEK BAŞINA YETMİYOR — klasik tuzak: `dart.library.io`
/// Flutter test VM'inde ve masaüstünde de DOĞRU, yani `flutter test`
/// mobil uygulamayı çekip var olmayan bir eklentiyle konuşmaya çalışırdı.
/// Üç katman var: (1) [supported] çalışma anı kapısı, (2) mobil uygulamanın
/// her metodu yumuşak düşüyor, (3) [instance] test için değiştirilebilir.
abstract class AdService {
  /// Etkin uygulama. Testler bunu [useForTest] ile değiştiriyor.
  ///
  /// Deponun `final X.instance` desenine göre bir SAPMA ve gerekçesi şu: hak
  /// duvarının üç yollu sözleşmesini (reklam hazır / hazır değil / tavan dolu)
  /// eklentisiz sınamanın başka yolu yok ve o sözleşme ürünün en kritik
  /// değişmezini taşıyor — kaydetme yolu asla kapanmaz.
  static AdService instance = createAdService();

  /// Yalnızca testler için: sahte bir servis koyar.
  @visibleForTesting
  static void useForTest(AdService value) => instance = value;

  /// Testten sonra gerçek uygulamayı geri koyar.
  @visibleForTesting
  static void resetForTest() => instance = createAdService();

  /// Bu platformda ödüllü reklam mümkün mü.
  bool get supported;

  /// Gösterilmeye hazır bir reklam var mı. `false` ise duvar reklam satırını
  /// HİÇ çizmiyor — hata göstermiyor.
  bool get isReady;

  Future<void> init();

  /// Arka planda bir reklam yükler. Ateşle-unut; başarısızlık sessiz.
  Future<void> preload();

  /// Reklamı gösterir. [nonce] sunucudan alınan belirteç; AdMob'a
  /// `customData` olarak gidiyor ve ödülün kime yazılacağını o belirliyor.
  Future<AdOutcome> showRewarded({required String nonce});

  void dispose();
}
