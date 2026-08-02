import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../domain/review_item.dart';
import '../domain/today_reviews_repository.dart';

/// [TodayReviewsRepository]'nin bellek içi (mock) uygulaması.
///
/// Gerçek veri katmanı (drift/Supabase) devreye alınana kadar UI'yı beslemek
/// için sabit örnek sorular döndürür. Küçük bir gecikme ile ağ/disk erişimini
/// taklit eder.
class MockTodayReviewsRepository implements TodayReviewsRepository {
  const MockTodayReviewsRepository();

  @override
  Future<List<ReviewItem>> dueReviews({required DateTime today}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final DateTime due = DateTime(today.year, today.month, today.day);

    ReviewSchedule schedule(String id, String questionId) => ReviewSchedule(
          id: id,
          studentId: 'demo',
          questionId: questionId,
          intervalDays: 1,
          easeFactor: 2.5,
          repetitions: 1,
          nextReviewDate: due,
          lastGrade: ReviewGrade.bilemedim,
        );

    return <ReviewItem>[
      ReviewItem(
        question: const Question(
          id: 'q1',
          conceptId: 'oran_oranti',
          type: QuestionType.tipC,
          difficulty: Difficulty.orta,
          text:
              'Bir işçi bir işi 6 günde, başka bir işçi aynı işi 12 günde bitiriyor. '
              'İkisi birlikte çalışırsa işi kaç günde bitirir?',
          correctAnswer: '4 gün',
          solutionSteps: <String>[
            'Birinci işçinin 1 günde yaptığı iş: 1/6',
            'İkinci işçinin 1 günde yaptığı iş: 1/12',
            'Birlikte 1 günde: 1/6 + 1/12 = 3/12 = 1/4',
            'Tüm iş 1 kabul edilirse süre: 1 ÷ (1/4) = 4 gün',
          ],
        ),
        schedule: schedule('rs1', 'q1'),
      ),
      ReviewItem(
        question: const Question(
          id: 'q2',
          conceptId: 'dik_ucgen_pisagor',
          type: QuestionType.tipA,
          difficulty: Difficulty.kolay,
          text:
              'Aşağıdaki dik üçgende |AB| = 3 birim ve |BC| = 4 birim ise '
              '|AC| kaç birimdir?',
          correctAnswer: '5 birim',
          solutionSteps: <String>[
            'B köşesindeki açı 90° olduğundan Pisagor uygulanır.',
            '|AC|² = |AB|² + |BC|² = 3² + 4² = 9 + 16 = 25',
            '|AC| = √25 = 5 birim',
          ],
          // Tip A: şekil parametrik olarak tanımlanır, çizim CustomPainter ile
          // matematiksel olarak doğru şekilde yapılır (diffusion görsel YOK).
          drawingParams: <String, dynamic>{
            'shape': 'triangle',
            'points': <Map<String, dynamic>>[
              <String, dynamic>{'x': 0.2, 'y': 0.82, 'label': 'B'},
              <String, dynamic>{'x': 0.2, 'y': 0.18, 'label': 'A'},
              <String, dynamic>{'x': 0.82, 'y': 0.82, 'label': 'C'},
            ],
            'rightAngleAt': 0,
          },
        ),
        schedule: schedule('rs2', 'q2'),
      ),
      ReviewItem(
        question: const Question(
          id: 'q3',
          conceptId: 'sayi_oruntuleri',
          type: QuestionType.tipC,
          difficulty: Difficulty.zor,
          text: '2, 5, 10, 17, ... sayı örüntüsünde 5. terim kaçtır?',
          correctAnswer: '26',
          solutionSteps: <String>[
            'Terimler n² + 1 kuralına uyar (n = 1, 2, 3, ...).',
            '1²+1=2, 2²+1=5, 3²+1=10, 4²+1=17',
            '5. terim: 5² + 1 = 26',
          ],
        ),
        schedule: schedule('rs3', 'q3'),
      ),
    ];
  }
}

/// Bugünün tekrarları için repository sağlayıcısı. İleride gerçek uygulamayla
/// değiştirmek için yalnızca bu satır güncellenir.
final todayReviewsRepositoryProvider = Provider<TodayReviewsRepository>(
  (ref) => const MockTodayReviewsRepository(),
);
