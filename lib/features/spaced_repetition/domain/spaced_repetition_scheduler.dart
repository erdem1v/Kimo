import 'dart:math' as math;

/// Bir soru–öğrenci çiftinin aralıklı tekrar (spaced repetition) durumu.
///
/// Tamamen saf bir veri sınıfıdır: Flutter'a, veritabanına veya herhangi bir
/// I/O'ya bağımlı değildir. Bu sayede [SpacedRepetitionScheduler] birim
/// testleriyle izole şekilde doğrulanabilir.
class SrsState {
  const SrsState({
    this.repetitions = 0,
    this.easeFactor = SpacedRepetitionScheduler.defaultEaseFactor,
    this.intervalDays = 0,
    this.nextReviewDate,
  });

  /// Üst üste verilen doğru cevap sayısı. Yanlış cevapta 0'a döner.
  final int repetitions;

  /// Kolaylık katsayısı (SM-2 "ease factor"). Doğru cevapta artar, yanlışta
  /// azalır; [SpacedRepetitionScheduler.minEaseFactor] alt sınırının altına
  /// inmez.
  final double easeFactor;

  /// Bir sonraki tekrara kadar gün cinsinden aralık.
  final int intervalDays;

  /// Bir sonraki tekrarın planlandığı tarih (saat bileşeni sıfırlanmış, güne
  /// normalize edilmiş). Henüz hiç planlanmadıysa `null`.
  final DateTime? nextReviewDate;

  /// Henüz hiç çalışılmamış bir soru için başlangıç durumu.
  static const SrsState initial = SrsState();

  SrsState copyWith({
    int? repetitions,
    double? easeFactor,
    int? intervalDays,
    DateTime? nextReviewDate,
  }) {
    return SrsState(
      repetitions: repetitions ?? this.repetitions,
      easeFactor: easeFactor ?? this.easeFactor,
      intervalDays: intervalDays ?? this.intervalDays,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SrsState &&
      other.repetitions == repetitions &&
      other.easeFactor == easeFactor &&
      other.intervalDays == intervalDays &&
      other.nextReviewDate == nextReviewDate;

  @override
  int get hashCode =>
      Object.hash(repetitions, easeFactor, intervalDays, nextReviewDate);

  @override
  String toString() =>
      'SrsState(repetitions: $repetitions, easeFactor: $easeFactor, '
      'intervalDays: $intervalDays, nextReviewDate: $nextReviewDate)';
}

/// SM-2 algoritmasının sadeleştirilmiş bir uygulaması (Anki'nin temel aldığı
/// algoritma).
///
/// Tasarım kararları:
/// * İlk tekrarlar sabit "öğrenme adımları" ([learningSteps]) üzerinden ilerler
///   (varsayılan: 1 → 3 → 7 → 14 → 30 gün). Böylece ürün spesifikasyonundaki
///   "ilk tekrar 1 gün sonra birebir aynı soru" davranışı sağlanır.
/// * Öğrenme adımları bitince aralık, klasik SM-2'deki gibi
///   `önceki_aralık * easeFactor` ile çarpımsal büyür.
/// * [easeFactor] her cevapta SM-2 formülüyle güncellenir ve
///   [minEaseFactor]'ın altına inmez.
///
/// Sınıf durumsuzdur (stateless) ve saf fonksiyon gibi davranır: aynı girdi
/// her zaman aynı çıktıyı üretir. Saat bağımlılığı olmaması için cevap tarihi
/// ([reviewedAt]) dışarıdan verilir.
class SpacedRepetitionScheduler {
  const SpacedRepetitionScheduler({
    this.learningSteps = defaultLearningSteps,
    this.minEaseFactor = defaultMinEaseFactor,
  });

  /// Yeni bir soru için başlangıç kolaylık katsayısı.
  static const double defaultEaseFactor = 2.5;

  /// Kolaylık katsayısının inebileceği en düşük değer.
  static const double defaultMinEaseFactor = 1.3;

  /// Varsayılan öğrenme adımları (gün).
  static const List<int> defaultLearningSteps = <int>[1, 3, 7, 14, 30];

  /// Doğru cevaplarda sırayla uygulanan sabit aralıklar (gün).
  final List<int> learningSteps;

  /// Kolaylık katsayısının alt sınırı.
  final double minEaseFactor;

  /// Bir cevap sonrası yeni tekrar durumunu hesaplar.
  ///
  /// [quality] 0–5 aralığında bir başarı notudur:
  /// * 0–2 → yanlış (seri sıfırlanır, soru ertesi gün tekrar sorulur),
  /// * 3   → zorlanarak doğru,
  /// * 4   → doğru,
  /// * 5   → kolayca doğru.
  ///
  /// [current] sorunun mevcut durumu, [reviewedAt] ise cevabın verildiği andır.
  SrsState schedule({
    required SrsState current,
    required int quality,
    required DateTime reviewedAt,
  }) {
    if (quality < 0 || quality > 5) {
      throw ArgumentError.value(quality, 'quality', '0 ile 5 arasında olmalı');
    }

    final double updatedEase = _updateEaseFactor(current.easeFactor, quality);

    final int repetitions;
    final int intervalDays;
    if (quality < 3) {
      // Yanlış cevap: seri sıfırlanır ve soru ertesi gün tekrar gösterilir.
      repetitions = 0;
      intervalDays = 1;
    } else {
      repetitions = current.repetitions + 1;
      if (repetitions <= learningSteps.length) {
        // Hâlâ öğrenme adımlarındayız: sabit aralığı kullan.
        intervalDays = learningSteps[repetitions - 1];
      } else {
        // Öğrenme adımları bitti: çarpımsal (SM-2) büyüme.
        final int base =
            current.intervalDays <= 0 ? learningSteps.last : current.intervalDays;
        intervalDays = math.max(1, (base * updatedEase).round());
      }
    }

    return SrsState(
      repetitions: repetitions,
      easeFactor: updatedEase,
      intervalDays: intervalDays,
      nextReviewDate: _dateOnly(reviewedAt).add(Duration(days: intervalDays)),
    );
  }

  /// SM-2 kolaylık katsayısı güncelleme formülü. Sonuç [minEaseFactor] ile
  /// aşağıdan sınırlanır.
  double _updateEaseFactor(double current, int quality) {
    final double q = quality.toDouble();
    final double updated =
        current + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    return updated < minEaseFactor ? minEaseFactor : updated;
  }

  /// Verilen tarihin yalnızca gün bileşenini (yerel gece yarısı) döndürür.
  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
