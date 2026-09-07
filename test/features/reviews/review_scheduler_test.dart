import 'package:ai_yks_coach/features/reviews/domain/review_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ReviewScheduler scheduler = ReviewScheduler();
  final DateTime today = DateTime(2026, 8, 2);

  group('ReviewScheduler', () {
    test('yeni hata: aynı gün başlar (gerçek vadeyi DB tetikleyicisi atar)', () {
      final ReviewOutcome r = scheduler.initial(createdOn: today);
      expect(r.step, 0);
      expect(r.mastered, false);
      expect(r.nextReviewDate, DateTime(2026, 8, 2));
    });

    test('tek seferde doğru 1 → 3 → 7 → 30 ilerler, sonra BAKIM basamağı', () {
      // Adım 0 doğru → 3 gün, adım 1
      final ReviewOutcome r1 =
          scheduler.review(step: 0, lapses: 0, correct: true, reviewedOn: today);
      expect(r1.step, 1);
      expect(r1.nextReviewDate, today.add(const Duration(days: 3)));

      // Adım 1 doğru → 7 gün, adım 2
      final ReviewOutcome r2 = scheduler.review(
          step: 1, lapses: 0, correct: true, reviewedOn: today);
      expect(r2.step, 2);
      expect(r2.nextReviewDate, today.add(const Duration(days: 7)));

      // Adım 2 doğru → 30 gün, adım 3
      final ReviewOutcome r3 = scheduler.review(
          step: 2, lapses: 0, correct: true, reviewedOn: today);
      expect(r3.step, 3);
      expect(r3.mastered, false);
      expect(r3.nextReviewDate, today.add(const Duration(days: 30)));

      // Adım 3 (son) doğru → KUYRUKTAN ÇIKMAZ: bakım basamağı, 45 gün.
      // Eski davranış (mastered = kalıcı çıkış) Task 03'te kaldırıldı.
      final ReviewOutcome r4 = scheduler.review(
          step: 3, lapses: 0, correct: true, reviewedOn: today);
      expect(r4.step, scheduler.maintenanceStep);
      expect(r4.mastered, false);
      expect(r4.nextReviewDate, today.add(const Duration(days: 45)));
    });

    test('bakım basamağı bakımda kalır: her doğru +45 gün', () {
      final ReviewOutcome r = scheduler.review(
          step: 4, lapses: 0, correct: true, reviewedOn: today);
      expect(r.step, scheduler.maintenanceStep);
      expect(r.mastered, false);
      expect(r.nextReviewDate, today.add(const Duration(days: 45)));
    });

    test('bakımda yanlış: merdivenin başına döner', () {
      final ReviewOutcome r = scheduler.review(
          step: 4, lapses: 0, correct: false, reviewedOn: today);
      expect(r.step, 0);
      expect(r.lapses, 1);
      expect(r.mastered, false);
      expect(r.nextReviewDate, DateTime(2026, 8, 3));
    });

    test('sınav tarihi bilinince: sonraki bakım sınavı aşarsa emekli olur', () {
      final DateTime exam = ReviewScheduler.examCutoffFor(2026)!;
      expect(exam, DateTime(2026, 6, 20));

      // Sınava 100 gün varken bakım tekrarı sığar → emekli DEĞİL.
      final ReviewOutcome fits = scheduler.review(
        step: 4,
        lapses: 0,
        correct: true,
        reviewedOn: DateTime(2026, 1, 10),
        examDate: exam,
      );
      expect(fits.mastered, false);

      // Sınava 20 gün kala +45 sığmaz → emekli.
      final ReviewOutcome retired = scheduler.review(
        step: 4,
        lapses: 0,
        correct: true,
        reviewedOn: DateTime(2026, 6, 1),
        examDate: exam,
      );
      expect(retired.mastered, true);

      // Merdivenden bakıma İLK geçişte de aynı kural işler.
      final ReviewOutcome fromLadder = scheduler.review(
        step: 3,
        lapses: 0,
        correct: true,
        reviewedOn: DateTime(2026, 6, 1),
        examDate: exam,
      );
      expect(fromLadder.step, scheduler.maintenanceStep);
      expect(fromLadder.mastered, true);
    });

    test('sınav yılı bilinmiyorsa süresiz bakımda kalır', () {
      final ReviewOutcome r = scheduler.review(
          step: 4, lapses: 0, correct: true, reviewedOn: DateTime(2030, 1, 1));
      expect(r.mastered, false);
      expect(ReviewScheduler.examCutoffFor(null), isNull);
    });

    test('yanlış: adım 0 ve 1 güne sıfırlar, lapses artar', () {
      final ReviewOutcome r = scheduler.review(
          step: 2, lapses: 0, correct: false, reviewedOn: today);
      expect(r.step, 0);
      expect(r.lapses, 1);
      expect(r.mastered, false);
      expect(r.nextReviewDate, DateTime(2026, 8, 3));
    });

    test('4+ sıfırlanmada leech işaretlenir', () {
      int lapses = 0;
      ReviewOutcome r = scheduler.initial(createdOn: today);
      for (int i = 0; i < 4; i++) {
        r = scheduler.review(
            step: r.step, lapses: lapses, correct: false, reviewedOn: today);
        lapses = r.lapses;
      }
      expect(r.lapses, 4);
      expect(r.isLeech, true);
      // Leech olunca yanlışta 1 gün değil cooldown (3 gün) sonra gelir.
      expect(r.nextReviewDate, today.add(const Duration(days: 3)));
    });

    test('nextReviewDate saatten bağımsız (güne normalize)', () {
      final DateTime withTime = DateTime(2026, 8, 2, 23, 59);
      final ReviewOutcome r = scheduler.review(
          step: 0, lapses: 0, correct: true, reviewedOn: withTime);
      expect(r.nextReviewDate, DateTime(2026, 8, 5)); // +3 gün
    });

    test('bozuk/aşırı step güvenli şekilde sınırlanır (bakıma kırpılır)', () {
      final ReviewOutcome r = scheduler.review(
          step: 99, lapses: 0, correct: true, reviewedOn: today);
      expect(r.step, scheduler.maintenanceStep);
      expect(r.mastered, false);
      expect(r.nextReviewDate, today.add(const Duration(days: 45)));
    });
  });
}
