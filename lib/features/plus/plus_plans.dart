import 'package:flutter/foundation.dart';

/// Kimo Plus planı.
///
/// `priceLabel` bir **metin**, sayı değil. Gerekçe: `in_app_purchase`'in
/// `ProductDetails.price` alanı zaten biçimlenmiş ve yerelleştirilmiş bir
/// metin döndürüyor (`"₺1.200,00"`). Yer tutucuyu da metin olarak modellemek,
/// abonelik task'ında değişimi `placeholder` → mağaza sorgusu seviyesinde
/// tutuyor; aşağıdaki hiçbir widget değişmiyor. Ayrıca `intl`'in
/// `NumberFormat` yerel verisi hiç devreye girmiyor.
@immutable
class PlusPlan {
  const PlusPlan({
    required this.id,
    required this.priceLabel,
    required this.perMonthLabel,
    this.savingPercent,
  });

  /// Mağaza ürün kimliği — abonelik task'ının eşleme anahtarı.
  final String id;

  /// Dönem fiyatı, gösterildiği hâliyle ("₺1.200").
  final String priceLabel;

  /// Aya indirgenmiş fiyat ("₺100").
  final String perMonthLabel;

  /// "%33 AVANTAJ" rozeti; yoksa `null`.
  final int? savingPercent;
}

/// Plus planları ve satın almanın açık olup olmadığı.
class PlusPlans {
  const PlusPlans._();

  /// Ücretsiz deneme süresi (gün).
  static const int trialDays = 7;

  /// YER TUTUCU FİYATLAR — MAĞAZADAN GELMİYOR. **YAYIN ENGELİ.**
  ///
  /// Apple 3.1.2 ve Play abonelik politikası, gösterilen fiyatın kullanıcının
  /// mağazasının kendi YERELLEŞTİRİLMİŞ fiyatı olmasını şart koşuyor. Burada
  /// ₺ sabit, yani bu tablo yalnızca dört kişilik iç test için güvenli.
  ///
  /// Abonelik task'ı `current` getter'ını `ProductDetails` sorgusuyla
  /// değiştirecek; `id` alanı eşleme anahtarı. CI'da `₺` karakteri için bir
  /// kapı var: bu dosya dışında hiçbir yerde fiyat yazılamıyor.
  static const List<PlusPlan> placeholder = <PlusPlan>[
    PlusPlan(
      id: 'kimo_plus_yearly',
      priceLabel: '₺1.200',
      perMonthLabel: '₺100',
      savingPercent: 33,
    ),
    PlusPlan(
      id: 'kimo_plus_monthly',
      priceLabel: '₺150',
      perMonthLabel: '₺150',
    ),
  ];

  /// Ekranın kullandığı liste. Abonelik task'ı burayı mağazaya bağlayacak.
  static List<PlusPlan> get current => placeholder;

  /// Varsayılan seçili plan: yıllık (tasarım kararı, "%33 AVANTAJ" onda).
  static PlusPlan get defaultPlan => current.first;

  /// Satın alma açık mı.
  ///
  /// `false` olduğu sürece: birincil düğme GÖRÜNÜR BİÇİMDE devre dışı ve
  /// altında dürüst bir satır duruyor; "Satın alımları geri yükle" ve
  /// "Aboneliği yönet" satırları **hiç çizilmiyor**.
  ///
  /// Neden çizilmiyor: `lib/services/legal_links.dart` aynı kararı yazıyor —
  /// *"'Hazırlanıyor' yer tutucusu bilinçli olarak geri getirilmedi: mağaza
  /// incelemesinde doğrudan sorulan şey oydu."* Hiçbir şeyi geri yüklemeyen
  /// bir "geri yükle" satırı kanonik bir App Store reddi.
  static bool get isConfigured => false;
}
