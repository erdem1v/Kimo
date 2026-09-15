import 'package:flutter/foundation.dart';

import '../features/plus/plus_plans.dart';

/// Mağaza satın alma katmanının SOYUTLAMASI.
///
/// NEDEN SOYUTLAMA: fiyatın, satın almanın ve geri yüklemenin tek kaynağı
/// mağaza olmalı (Apple 3.1.2, Play abonelik politikası) ama mağaza
/// eklentisi bu depoya HENÜZ EKLENEMEDİ — `pubspec.lock` `pub.dev`'den gelen
/// sha256 özetlerini taşıyor ve bu makinede Flutter/Dart yok, yani kilit
/// dosyası üretilemiyor. CI'da `git diff --exit-code pubspec.lock` kapısı
/// olduğu için bağımlılığı kilitsiz eklemek işi KESİN kırmızıya düşürürdü.
///
/// Bu yüzden katmanın TAMAMI burada duruyor ve mağazaya bağlanan tek parça
/// [PurchaseService] gerçeklemesi. Eklenti geldiğinde yazılacak tek dosya o.
/// Adımlar `docs/task-13-kapanis-raporu.md`'de sırayla yazılı.
///
/// BUGÜNKÜ SONUÇ ÖNEMLİ: uygulama ARTIK SABİT FİYAT GÖSTERMİYOR. Eskiden
/// `plus_plans.dart` sabit TL yer tutucularını hem paywall'da hem hak
/// duvarında ÇİZİYORDU ve bu bir yayın engeliydi. Artık fiyat yalnızca mağaza
/// yanıtından geliyor; yanıt yoksa fiyat İÇEREN hiçbir metin çizilmiyor.
abstract class PurchaseService {
  /// Mağazanın döndürdüğü planlar. Boş liste = mağaza yok/yanıt yok.
  ///
  /// `priceLabel` MAĞAZANIN yerelleştirilmiş metni (`ProductDetails.price`),
  /// bizim biçimlediğimiz bir sayı değil.
  Future<List<PlusPlan>> products();

  /// Satın almayı başlatır. `true` = akış başlatıldı (tamamlanma sunucudan
  /// doğrulanınca `my_daily_state.ai_tier` premium olur).
  Future<bool> buy(PlusPlan plan);

  /// "Satın alımları geri yükle". Apple bunu ZORUNLU tutuyor.
  Future<bool> restore();

  /// "Aboneliği yönet" derin bağlantısı; platform mağazasına gider.
  Uri? manageUri();
}

/// Mağaza yokken kullanılan gerçekleme.
///
/// Hiçbir şey yapmıyor ve bunu GİZLEMİYOR: `products()` boş liste döndürüyor,
/// dolayısıyla `PlusPlans.isConfigured` false kalıyor ve paywall bugünkü
/// dürüst hâlinde duruyor — düğme görünür biçimde devre dışı, "Satın alımları
/// geri yükle" ve "Aboneliği yönet" satırları HİÇ çizilmiyor.
///
/// Hiçbir şeyi geri yüklemeyen bir "geri yükle" satırı kanonik bir App Store
/// reddi; `lib/services/legal_links.dart` aynı kararı yazıyor.
@immutable
class UnavailablePurchaseService implements PurchaseService {
  const UnavailablePurchaseService();

  @override
  Future<List<PlusPlan>> products() async => const <PlusPlan>[];

  @override
  Future<bool> buy(PlusPlan plan) async => false;

  @override
  Future<bool> restore() async => false;

  @override
  Uri? manageUri() => null;
}

/// Uygulamanın kullandığı gerçeklemenin tek kaydı.
///
/// Mağaza eklentisi geldiğinde `main.dart` açılışta [instance]'ı gerçek
/// gerçeklemeyle değiştirecek; başka hiçbir dosya değişmeyecek.
///
/// NEDEN SINIF İÇİNDE STATİK: depo veri katmanını dosya sonundaki `final`
/// singleton'larla dağıtıyor (`dailyStateRepository` gibi), ama bu alan
/// DEĞİŞTİRİLEBİLİR olmak zorunda — `final` bir üst düzey değişken hem
/// takasa izin vermez hem `tools/check_imports.py`'nin tanıdığı bildirim
/// biçimlerinin dışında kalır.
class Purchases {
  const Purchases._();

  static PurchaseService instance = const UnavailablePurchaseService();
}
