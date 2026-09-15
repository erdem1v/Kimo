/// Analiz hakkının durumu — SUNUCUNUN söylediği hâliyle.
///
/// Bu enum bir gösterim kararı değil, sunucudaki `public.ai_state()`
/// fonksiyonunun `state` sütununun birebir karşılığı. İstemci eşik
/// hesaplamıyor, saat çıkarmıyor, "az kaldı"yı kendisi tayin etmiyor: hangi
/// durumda olduğunu sunucu söylüyor (bkz. göç 0075 ve
/// `docs/task-10-reklam-raporu.md`).
///
/// ADI NEDEN "hak": kayan pencerede hak zamanla geri geliyor, tükenen bir
/// yaşam değil. Task 10 bu gerekçeyle hem kalp ikonunu hem eski kelimeyi
/// kaldırmıştı.
///
/// TASK 12'DE İKONUN TARAFI DEĞİŞTİ, ADIN TARAFI DEĞİŞMEDİ: onaylanan tasarım
/// (Tur 7 · n1) tek kalp + rakam kullanıyor — Task 10'un reddettiği şey
/// kalbin hak sayısı kadar TEKRARLANMASIYDI ve o tekrar yok. Arayüz metinleri
/// ve bu enum "hak" demeye devam ediyor; eski kelimeyi yasaklayan CI kapısı
/// yerinde.
enum AiState {
  /// Hak bol.
  ok,

  /// Az kaldı — sayı VE sonraki hakkın saati gösteriliyor.
  low,

  /// 8 saatlik pencere doldu — sonraki hakkın saati gösteriliyor.
  windowFull,

  /// Aylık sınır doldu — ay yenilenme tarihi gösteriliyor.
  ///
  /// Bu durumda pencere saati GÖSTERİLMEZ: o saat artık bir şey vaat
  /// etmiyor, çünkü pencere açılsa da aylık cap kapalı.
  monthFull,

  /// Anonim kullanıcının ömür boyu hakkı doldu. Gösterilecek saat yok;
  /// yol hesap açmaktan geçiyor.
  lifetimeFull,

  /// Kullanıcı askıya alınmış. Analiz sonucunu kaydedemeyeceği için hak da
  /// harcatılmıyor.
  suspended;

  /// Sunucu değerini çevirir. **Tanınmayan ya da eksik değer `null`** —
  /// varsayılan DEĞİL.
  ///
  /// Gerekçe: bilinmeyen bir durum "okunamadı"dır, tahmin edilecek bir şey
  /// değil. Arayüz `null`'da hiçbir şey çizmiyor; sıfır göstermek gerçekten
  /// sıfır olmasıyla ayırt edilemezdi — eski `?? 5` / `?? 0` yedeklerinin
  /// ürettiği hata tam buydu.
  static AiState? fromDb(String? value) => switch (value) {
    'ok' => AiState.ok,
    'low' => AiState.low,
    'window_full' => AiState.windowFull,
    'month_full' => AiState.monthFull,
    'lifetime_full' => AiState.lifetimeFull,
    'suspended' => AiState.suspended,
    _ => null,
  };

  /// Hak harcanabilir mi. Arayüz kapısı DEĞİL — sunucu zaten reddediyor;
  /// yalnızca hangi yüzeyin çizileceğini seçmek için.
  bool get hasCredit => this == AiState.ok || this == AiState.low;

  /// Duvarın (hak bitti ekranının) açılacağı durumlar.
  bool get isWall =>
      this == AiState.windowFull ||
      this == AiState.monthFull ||
      this == AiState.lifetimeFull;
}

/// Kullanıcının katmanı. Sunucudaki `public.user_tier()` karşılığı.
///
/// `premium` bu sürümde ŞEMA DÜZEYİNDE var ama dolduran bir yol yok: abonelik
/// satın alma ayrı bir task ve `profiles.premium_until` sütununu o yazacak.
/// İç testte elle SQL ile set ediliyor.
enum AiTier {
  anonymous,
  free,
  premium;

  static AiTier? fromDb(String? value) => switch (value) {
    'anonymous' => AiTier.anonymous,
    'free' => AiTier.free,
    'premium' => AiTier.premium,
    _ => null,
  };
}
