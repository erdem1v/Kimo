/// Bir tekrar hesaplamasının sonucu (yeni plan durumu). Saf veri sınıfı.
class ReviewOutcome {
  const ReviewOutcome({
    required this.step,
    required this.lapses,
    required this.isLeech,
    required this.mastered,
    required this.nextReviewDate,
  });

  /// Kaçıncı adımda (0 tabanlı; adım listesine indeks).
  final int step;

  /// Kaç kez 1 güne sıfırlandığı (yanlış sayısı).
  final int lapses;

  /// İnatçı hata mı (çok kez sıfırlandı).
  final bool isLeech;

  /// Kalıcı öğrenildi mi (kuyruktan çıkar).
  final bool mastered;

  /// Bir sonraki tekrar tarihi (güne normalize edilmiş).
  final DateTime nextReviewDate;

  @override
  bool operator ==(Object other) =>
      other is ReviewOutcome &&
      other.step == step &&
      other.lapses == lapses &&
      other.isLeech == isLeech &&
      other.mastered == mastered &&
      other.nextReviewDate == nextReviewDate;

  @override
  int get hashCode => Object.hash(step, lapses, isLeech, mastered, nextReviewDate);

  @override
  String toString() => 'ReviewOutcome(step: $step, lapses: $lapses, '
      'isLeech: $isLeech, mastered: $mastered, next: $nextReviewDate)';
}

/// Aralıklı tekrar protokolü: sabit adımlar (varsayılan 1 → 3 → 7 → 30 gün).
///
/// * Tek seferde doğru → bir sonraki adıma geçer.
/// * Son adım (30 gün) doğruysa → `mastered` (kalıcı öğrenildi).
/// * Yanlış → 0. adıma (1 güne) sıfırlanır ve `lapses` artar.
/// * `lapses >= leechThreshold` → `isLeech` (kavramı baştan çalış sinyali).
///
/// Saat bağımlılığı olmaması için tekrar tarihi ([reviewedOn]) dışarıdan verilir.
class ReviewScheduler {
  const ReviewScheduler({
    this.steps = defaultSteps,
    this.leechThreshold = 4,
  });

  static const List<int> defaultSteps = <int>[1, 3, 7, 30];

  final List<int> steps;
  final int leechThreshold;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  int _clampStep(int step) {
    if (step < 0) return 0;
    if (step >= steps.length) return steps.length - 1;
    return step;
  }

  /// Yeni eklenen bir hata için başlangıç planı: bugün eklendi → ilk adım
  /// kadar (varsayılan 1 gün) sonra tekrar.
  ReviewOutcome initial({required DateTime createdOn}) {
    return ReviewOutcome(
      step: 0,
      lapses: 0,
      isLeech: false,
      mastered: false,
      nextReviewDate: _dateOnly(createdOn).add(Duration(days: steps.first)),
    );
  }

  /// Bir tekrar sonucunu uygular ve yeni planı döndürür.
  ReviewOutcome review({
    required int step,
    required int lapses,
    required bool correct,
    required DateTime reviewedOn,
  }) {
    final DateTime today = _dateOnly(reviewedOn);
    final int current = _clampStep(step);

    if (correct) {
      final bool graduated = current >= steps.length - 1;
      final int newStep = graduated ? current : current + 1;
      return ReviewOutcome(
        step: newStep,
        lapses: lapses,
        isLeech: lapses >= leechThreshold,
        mastered: graduated,
        nextReviewDate: today.add(Duration(days: steps[newStep])),
      );
    }

    final int newLapses = lapses + 1;
    return ReviewOutcome(
      step: 0,
      lapses: newLapses,
      isLeech: newLapses >= leechThreshold,
      mastered: false,
      nextReviewDate: today.add(Duration(days: steps.first)),
    );
  }
}
