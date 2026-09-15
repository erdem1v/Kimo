import 'package:flutter/foundation.dart';

/// Kimo Plus planı.
///
/// `priceLabel` bir **metin**, sayı değil. Gerekçe: mağazaların döndürdüğü
/// fiyat alanı (`ProductDetails.price`) zaten biçimlenmiş ve YERELLEŞTİRİLMİŞ
/// bir metin (örneğin "1.200,00 TL" ya da "$4.99"). Yer tutucuyu da metin olarak modellemek,
/// mağazaya geçişi tek bir noktada tutuyor ve `intl`'in `NumberFormat` yerel
/// verisi hiç devreye girmiyor.
@immutable
class PlusPlan {
  const PlusPlan({
    required this.id,
    required this.priceLabel,
    required this.perMonthLabel,
    this.savingPercent,
  });

  /// Mağaza ürün kimliği — eşleme anahtarı. SIR DEĞİL: herkese açık bir
  /// tanımlayıcı, bu yüzden `supabase.json`'a değil koda yazılıyor (AdMob
  /// birim kimliklerinden farklı olarak, onlar hesaba bağlı).
  final String id;

  /// Dönem fiyatı, MAĞAZANIN gösterdiği hâliyle.
  final String priceLabel;

  /// Aya indirgenmiş fiyat.
  final String perMonthLabel;

  /// "%33 AVANTAJ" rozeti; yoksa `null`.
  final int? savingPercent;
}

/// Plus planları ve satın almanın açık olup olmadığı.
///
/// ================== SABİT FİYAT KALDIRILDI (Task 13) ======================
///
/// Bu dosya Task 10'dan beri `1.200` / `150` TL yer tutucularını taşıyordu ve
/// kendi yorumu bunu **YAYIN ENGELİ** ilan ediyordu: Apple 3.1.2 ve Play
/// abonelik politikası, gösterilen fiyatın kullanıcının mağazasının kendi
/// YERELLEŞTİRİLMİŞ fiyatı olmasını şart koşuyor. Yer tutucular yalnızca
/// "dört kişilik iç test için güvenli" sayılmıştı — ama hem paywall'da hem
/// HAK DUVARINDA canlı çiziliyorlardı.
///
/// Artık fiyat YALNIZCA mağazadan geliyor. Mağaza yanıtı yoksa:
///   * [current] boş,
///   * [isConfigured] false,
///   * ve fiyat İÇEREN hiçbir metin çizilmiyor.
///
/// Yani "satın alma kapalıyken sabit fiyat gösterme" kusuru, mağaza eklentisi
/// gelmeden de kapandı. CI kapısı da buna göre sertleşti: artık `lib/` içinde
/// HİÇBİR dosyada TL işareti yazamıyor (bu dosyanın muafiyeti kaldırıldı).
class PlusPlans {
  const PlusPlans._();

  /// Ücretsiz deneme süresi (gün).
  ///
  /// UYGUNLUĞU BİZ ZORLAMIYORUZ ve zorlamaya çalışmayacağız: deneme hakkı
  /// MAĞAZA HESABINA bağlı (Apple ID / Google hesabı), bizim `auth.uid()`
  /// kimliğimize değil. Apple introductory offer eligibility'yi, Play de
  /// `oneTimeOnly` teklifini kendisi kontrol ediyor. Sunucu denemeyi yalnızca
  /// `status = 'trial'` olarak KAYDEDİYOR.
  static const int trialDays = 7;

  /// Mağazada tanımlı ürün kimlikleri. İkisi de AYNI abonelik grubunda
  /// olmalı (App Store: subscription group; Play: tek abonelik, iki base
  /// plan) — aksi hâlde kullanıcı iki aboneliğe birden sahip olabilir ve
  /// yükseltme/düşürme akışı çalışmaz.
  static const String yearlyId = 'kimo_plus_yearly';
  static const String monthlyId = 'kimo_plus_monthly';
  static const List<String> productIds = <String>[yearlyId, monthlyId];

  static List<PlusPlan> _current = const <PlusPlan>[];

  /// Ekranın kullandığı liste — MAĞAZADAN. Sorgu yanıtlanana kadar boş.
  static List<PlusPlan> get current => _current;

  /// Mağaza yanıtını yerleştirir. Tek çağıranı satın alma katmanı.
  ///
  /// SIRA KORUNUYOR: yıllık önce (tasarım kararı, "%33 AVANTAJ" onda ve
  /// varsayılan seçili o).
  static void setProducts(List<PlusPlan> products) {
    final List<PlusPlan> sorted = <PlusPlan>[
      for (final String id in productIds)
        ...products.where((PlusPlan p) => p.id == id),
    ];
    _current = List<PlusPlan>.unmodifiable(sorted);
  }

  /// Varsayılan seçili plan: yıllık. Liste boşsa `null`.
  static PlusPlan? get defaultPlan => _current.isEmpty ? null : _current.first;

  /// Satın alma açık mı.
  ///
  /// ARTIK DERLEME ZAMANI SABİTİ DEĞİL, ÇALIŞMA ZAMANI DURUMU: mağaza ürün
  /// döndürdüyse açık. `SupabaseConfig.isConfigured` ve `LegalLinks.has()` ile
  /// aynı kural — yapılandırılmamış olmak, özelliğin olmaması demek.
  ///
  /// `false` olduğu sürece: birincil düğme GÖRÜNÜR BİÇİMDE devre dışı ve
  /// altında dürüst bir satır duruyor; "Satın alımları geri yükle" ve
  /// "Aboneliği yönet" satırları **hiç çizilmiyor**.
  ///
  /// Neden çizilmiyor: `lib/services/legal_links.dart` aynı kararı yazıyor —
  /// *"'Hazırlanıyor' yer tutucusu bilinçli olarak geri getirilmedi: mağaza
  /// incelemesinde doğrudan sorulan şey oydu."* Hiçbir şeyi geri yüklemeyen
  /// bir "geri yükle" satırı kanonik bir App Store reddi.
  static bool get isConfigured => _current.isNotEmpty;

  /// Yalnızca test için: mağaza durumunu sıfırlar.
  @visibleForTesting
  static void resetForTest() => _current = const <PlusPlan>[];
}
