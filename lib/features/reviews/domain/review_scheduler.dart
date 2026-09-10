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

/// Aralıklı tekrar protokolü: sabit adımlar (varsayılan 1 → 3 → 7 → 30 gün)
/// + sınava kadar süren BAKIM basamağı.
///
/// * Tek seferde doğru → bir sonraki adıma geçer.
/// * Son adım (30 gün) doğruysa → **bakım basamağı** ([maintenanceStep]):
///   soru kuyruğu TERK ETMEZ, [maintenanceIntervalDays] arayla seyrek döner.
///   Eski davranış (`mastered = true` = kalıcı çıkış) Task 03'te kaldırıldı:
///   toplam ömür ~41 gündü ve eylülde öğrenilen konu haziran sınavına kadar
///   bir daha hiç sorulmuyordu — ürünün vaadi tam tersiyken.
/// * `mastered` yalnızca bir SONRAKİ bakım tekrarı sınav tarihini aşacaksa
///   `true` olur ([examDate] verilmişse). Sınav yılı bilinmiyorsa soru
///   süresiz bakımda kalır — yanlış "öğrenildi" demekten iyidir.
/// * Yanlış → 0. adıma (1 güne) sıfırlanır ve `lapses` artar (bakımdan da).
/// * `lapses >= leechThreshold` → `isLeech` (kavramı baştan çalış sinyali).
///
/// **ÖZ-RAPORLU DOĞRU ([review]'ün `selfReported` bayrağı, Task 08):** şıkları
/// olmayan eski satırlarda kullanıcı "Doğru çözdüm / Bilemedim" ile kendi
/// kendini değerlendiriyor. O beyan, işaretlenmiş bir şık kadar kanıt değil:
/// dört kez "doğru çözdüm" diyen öğrenci hiç öğrenmediği soruyu kalıcı arşive
/// atabiliyordu. Bu yüzden beyanla gelen doğru
///   • merdivende ilerler (yol kapanmıyor) ama aralık BİR KADEME KISA
///     uygulanır — soru takvimde daha yavaş uzaklaşır;
///   • `mastered` ASLA yazmaz. "Öğrenildi" damgası yalnızca gerçekten şık
///     işaretlenmiş bir doğrudan çıkabilir.
/// Yanlış cevabın davranışı iki yolda da aynı: beyanla "bilemedim" demek
/// şıklı yanlışla aynı sonucu doğurur, çünkü orada abartma güdüsü yok.
///
/// Saat bağımlılığı olmaması için tekrar tarihi ([reviewedOn]) dışarıdan verilir.
class ReviewScheduler {
  const ReviewScheduler({
    this.steps = defaultSteps,
    this.leechThreshold = defaultLeechThreshold,
    this.leechCooldownDays = 3,
    this.maintenanceIntervalDays = defaultMaintenanceIntervalDays,
  });

  static const List<int> defaultSteps = <int>[1, 3, 7, 30];

  /// "İnatçı" eşiği: kaç sıfırlanmadan sonra soru inatçı sayılır.
  ///
  /// TEK KAYNAK (Task 08). Aynı sayı eskiden `MistakeStats` içinde ikinci kez
  /// yazılıydı ve bir test eşitliklerini iddia ediyordu; ayrışırlarsa arayüz
  /// gerçekte olmayan bir kural anlatırdı. Arayüz metinleri de bu sayıya
  /// bağlı ("Seni en az dört kez yenen sorular" — `mistakesLeechBody`).
  static const int defaultLeechThreshold = 4;

  /// Bakım aralığı: merdivenin son adımından (30 gün) uzun, ama bir sınav
  /// dönemine birden fazla tekrar sığdıracak kadar kısa.
  static const int defaultMaintenanceIntervalDays = 45;

  final List<int> steps;
  final int leechThreshold;
  final int leechCooldownDays;
  final int maintenanceIntervalDays;

  /// Bakım basamağının indeksi (merdiven adımlarının hemen sonrası).
  /// Varsayılan merdivende 4. `step >= maintenanceStep` bakımda demektir.
  int get maintenanceStep => steps.length;

  /// Sınav yılı bilinen kullanıcı için tekrarların kesileceği tarih.
  ///
  /// YKS haziran ortasında; ayın 20'si güvenli üst sınır. Yıl bilinmiyorsa
  /// null döner ve bakım süresiz sürer.
  static DateTime? examCutoffFor(int? examYear) =>
      examYear == null ? null : DateTime(examYear, 6, 20);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  int _clampStep(int step) {
    if (step < 0) return 0;
    if (step > maintenanceStep) return maintenanceStep;
    return step;
  }

  /// Yeni eklenen bir hata için başlangıç planı.
  ///
  /// NOT: canlı akışta ilk vade artık VERİTABANI tetikleyicisinde atanıyor
  /// (aynı gün, kayıttan ~3 saat sonra — bkz. 0049 göçü). Bu metot yalnızca
  /// saf hesap katmanının sözleşmesini belgeliyor.
  ReviewOutcome initial({required DateTime createdOn}) {
    return ReviewOutcome(
      step: 0,
      lapses: 0,
      isLeech: false,
      mastered: false,
      nextReviewDate: _dateOnly(createdOn),
    );
  }

  /// Bir tekrar sonucunu uygular ve yeni planı döndürür.
  ///
  /// [examDate]: kullanıcının sınav tarihi (bkz. [examCutoffFor]). Bakım
  /// basamağında bir sonraki tekrar bu tarihi aşacaksa soru artık emekli
  /// edilir (`mastered = true`).
  ///
  /// [selfReported]: doğruluk kullanıcının BEYANINDAN geliyor (şık
  /// işaretlenmedi). Sınıf başlığındaki kurala göre aralık bir kademe kısa
  /// uygulanır ve `mastered` yazılmaz.
  ReviewOutcome review({
    required int step,
    required int lapses,
    required bool correct,
    required DateTime reviewedOn,
    DateTime? examDate,
    bool selfReported = false,
  }) {
    final DateTime today = _dateOnly(reviewedOn);
    final int current = _clampStep(step);

    if (correct) {
      final int newStep =
          current >= steps.length - 1 ? maintenanceStep : current + 1;
      // Bir kademe kısa = YENİ adımın aralığı yerine BULUNULAN adımınki.
      // Bakımdaki bir soruda `current` merdivenin dışında olabilir; o zaman
      // en uzun merdiven adımı (30) kullanılıyor — bakım aralığından (45)
      // kısa, yani kural orada da tutuyor.
      final int interval = selfReported
          ? (current >= steps.length ? steps.last : steps[current])
          : (newStep == maintenanceStep
              ? maintenanceIntervalDays
              : steps[newStep]);
      final DateTime next = today.add(Duration(days: interval));
      // Emeklilik yalnızca bakımda ve yalnızca sınav tarihi biliniyorsa:
      // bir sonraki bakım tekrarı sınavdan sonraya düşecekse artık sormanın
      // pedagojik değeri yok. Beyanla gelen doğru bu kapıdan GEÇEMEZ.
      final bool retired = !selfReported &&
          newStep == maintenanceStep &&
          examDate != null &&
          next.isAfter(examDate);
      return ReviewOutcome(
        step: newStep,
        lapses: lapses,
        isLeech: lapses >= leechThreshold,
        mastered: retired,
        nextReviewDate: next,
      );
    }

    final int newLapses = lapses + 1;
    final bool leech = newLapses >= leechThreshold;
    // Leech (inatçı hata) ise günlük döngüyü kırmak için daha uzun bekleme.
    final int wrongInterval = leech ? leechCooldownDays : steps.first;
    return ReviewOutcome(
      step: 0,
      lapses: newLapses,
      isLeech: leech,
      mastered: false,
      nextReviewDate: today.add(Duration(days: wrongInterval)),
    );
  }
}
