import 'package:ai_yks_coach/features/spaced_repetition/domain/spaced_repetition_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scheduler = SpacedRepetitionScheduler();
  final reviewedAt = DateTime(2026, 8, 2);

  group('SpacedRepetitionScheduler', () {
    test('ilk doğru cevap interval=1 ve nextReviewDate=ertesi gün verir', () {
      final result = scheduler.schedule(
        current: SrsState.initial,
        quality: 4,
        reviewedAt: reviewedAt,
      );

      expect(result.repetitions, 1);
      expect(result.intervalDays, 1);
      expect(result.nextReviewDate, DateTime(2026, 8, 3));
      // q=4 kolaylık katsayısını değiştirmez.
      expect(result.easeFactor, closeTo(2.5, 1e-9));
    });

    test('üst üste doğru cevaplar 1 → 3 → 7 → 14 → 30 ilerler', () {
      var state = SrsState.initial;
      const expectedIntervals = <int>[1, 3, 7, 14, 30];

      for (final expected in expectedIntervals) {
        state = scheduler.schedule(
          current: state,
          quality: 4,
          reviewedAt: reviewedAt,
        );
        expect(state.intervalDays, expected);
      }
      expect(state.repetitions, 5);
    });

    test('öğrenme adımları bitince interval easeFactor ile çarpımsal büyür', () {
      var state = SrsState.initial;
      for (var i = 0; i < 5; i++) {
        state = scheduler.schedule(
          current: state,
          quality: 4,
          reviewedAt: reviewedAt,
        );
      }
      // 5 adım sonra: interval=30, easeFactor=2.5 (q=4 sabit).
      expect(state.intervalDays, 30);
      expect(state.easeFactor, closeTo(2.5, 1e-9));

      final sixth = scheduler.schedule(
        current: state,
        quality: 4,
        reviewedAt: reviewedAt,
      );
      expect(sixth.repetitions, 6);
      expect(sixth.intervalDays, (30 * state.easeFactor).round()); // 75
    });

    test('yanlış cevap repetitions=0 ve interval=1 yapar', () {
      var state = SrsState.initial;
      for (var i = 0; i < 3; i++) {
        state = scheduler.schedule(
          current: state,
          quality: 5,
          reviewedAt: reviewedAt,
        );
      }
      expect(state.repetitions, 3);

      final wrong = scheduler.schedule(
        current: state,
        quality: 2,
        reviewedAt: reviewedAt,
      );
      expect(wrong.repetitions, 0);
      expect(wrong.intervalDays, 1);
      expect(wrong.nextReviewDate, DateTime(2026, 8, 3));
    });

    test('kolay (q=5) cevapta easeFactor artar', () {
      final result = scheduler.schedule(
        current: SrsState.initial,
        quality: 5,
        reviewedAt: reviewedAt,
      );
      expect(result.easeFactor, greaterThan(2.5));
    });

    test('tekrar eden yanlışlarda easeFactor 1.3 alt sınırının altına inmez', () {
      var state = SrsState.initial;
      for (var i = 0; i < 20; i++) {
        state = scheduler.schedule(
          current: state,
          quality: 0,
          reviewedAt: reviewedAt,
        );
      }
      expect(state.easeFactor, 1.3);
      expect(state.intervalDays, 1);
      expect(state.repetitions, 0);
    });

    test('nextReviewDate saat bileşeninden bağımsızdır (güne normalize)', () {
      final withTime = DateTime(2026, 8, 2, 15, 30, 45);
      final result = scheduler.schedule(
        current: SrsState.initial,
        quality: 4,
        reviewedAt: withTime,
      );
      expect(result.nextReviewDate, DateTime(2026, 8, 3));
    });

    test('geçersiz quality ArgumentError fırlatır', () {
      expect(
        () => scheduler.schedule(
          current: SrsState.initial,
          quality: 6,
          reviewedAt: reviewedAt,
        ),
        throwsArgumentError,
      );
      expect(
        () => scheduler.schedule(
          current: SrsState.initial,
          quality: -1,
          reviewedAt: reviewedAt,
        ),
        throwsArgumentError,
      );
    });
  });
}
