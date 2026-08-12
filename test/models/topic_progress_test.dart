import 'package:ai_yks_coach/models/topic_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TopicProgress p({int attempts = 0, int correct = 0, int daysAgo = 0}) {
    final DateTime now = DateTime.now();
    return TopicProgress(
      subject: 'Matematik',
      concept: 'Türev',
      attempts: attempts,
      correct: correct,
      lastAt: attempts == 0
          ? null
          : DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: daysAgo)),
    );
  }

  group('durum', () {
    test('hiç çözülmemişse "dokunulmamış"', () {
      expect(p().state, TopicState.untouched);
      expect(p().successRate, isNull);
      expect(p().needsAttention, isFalse);
    });

    test('15 sorudan azsa "ölçülüyor"', () {
      expect(p(attempts: 1, correct: 1).state, TopicState.inProgress);
      expect(p(attempts: 14, correct: 14).state, TopicState.inProgress);
    });

    test('15 ve üzeri "ölçüldü"', () {
      expect(p(attempts: 15, correct: 10).state, TopicState.measured);
    });
  });

  group('doluluk', () {
    test('15 soruda tamamlanır', () {
      expect(p().fill, 0);
      expect(p(attempts: 3).fill, closeTo(0.2, 0.001));
      expect(p(attempts: 15).fill, 1);
      expect(p(attempts: 40).fill, 1); // taşmaz
    });

    test('kalan soru sayısı doğru', () {
      expect(p(attempts: 12, correct: 8).remaining, 3);
      expect(p(attempts: 15, correct: 8).remaining, 0);
      expect(p(attempts: 99, correct: 8).remaining, 0);
    });
  });

  group('başarı', () {
    test('düşük başarı dikkat ister', () {
      expect(p(attempts: 20, correct: 6).needsAttention, isTrue); // %30
      expect(p(attempts: 20, correct: 16).needsAttention, isFalse); // %80
    });

    test('yeterli veri yokken dikkat uyarısı verilmez', () {
      // 2/10 kötü ama henüz ölçüm tamamlanmadı: erken yargı yok.
      expect(p(attempts: 10, correct: 2).needsAttention, isFalse);
    });

    test('yüzde yuvarlanır', () {
      expect(p(attempts: 20, correct: 15).successPercent, 75);
    });
  });

  group('solma', () {
    test('bugün çalışıldıysa taze', () {
      expect(p(attempts: 15, correct: 12).freshness, 1);
    });

    test('zamanla solar ve dibi görür', () {
      final double mid = p(attempts: 15, correct: 12, daysAgo: 15).freshness;
      expect(mid, closeTo(0.5, 0.01));
      expect(p(attempts: 15, correct: 12, daysAgo: 30).freshness, 0);
      expect(p(attempts: 15, correct: 12, daysAgo: 90).freshness, 0);
    });

    test('hiç çalışılmamışta tazelik 0', () {
      expect(p().freshness, 0);
    });
  });

  group('koç mesajı', () {
    test('ölçüm sürerken kaç soru kaldığını söyler', () {
      expect(p(attempts: 12, correct: 9).coachMessage, contains('3 soru'));
    });

    test('zayıf konuda uyarır', () {
      expect(p(attempts: 20, correct: 5).coachMessage, contains('zorlanıyorsun'));
    });

    test('uzun süre bakılmayan sağlam konuyu hatırlatır', () {
      final String m =
          p(attempts: 20, correct: 18, daysAgo: 40).coachMessage;
      expect(m, contains('uzun zamandır'));
    });
  });
}
