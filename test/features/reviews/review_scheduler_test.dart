import 'package:ai_yks_coach/features/reviews/domain/review_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ReviewScheduler scheduler = ReviewScheduler();
  final DateTime today = DateTime(2026, 8, 2);

  group('ReviewScheduler', () {
    test('yeni hata: ertesi gün tekrar (adım 0)', () {
      final ReviewOutcome r = scheduler.initial(createdOn: today);
      expect(r.step, 0);
      expect(r.mastered, false);
      expect(r.nextReviewDate, DateTime(2026, 8, 3));
    });

    test('tek seferde doğru 1 → 3 → 7 → 30 ilerler, sonra mastered', () {
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

      // Adım 3 (son) doğru → mastered
      final ReviewOutcome r4 = scheduler.review(
          step: 3, lapses: 0, correct: true, reviewedOn: today);
      expect(r4.mastered, true);
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

    test('bozuk/aşırı step güvenli şekilde sınırlanır', () {
      final ReviewOutcome r = scheduler.review(
          step: 99, lapses: 0, correct: true, reviewedOn: today);
      expect(r.mastered, true); // son adım gibi davranır
    });
  });
}
