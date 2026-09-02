import 'package:ai_yks_coach/features/mistakes/mistake_stats.dart';
import 'package:ai_yks_coach/features/reviews/domain/review_scheduler.dart';
import 'package:ai_yks_coach/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Hatalarım" ekranının gösterdiği her sayı burada iddia ediliyor.
///
/// Bu sayıların hiçbiri sunucudan gelmiyor: hepsi mevcut alanlardan
/// (`mastered`, `is_leech`, `lapses`, `created_at`) türüyor. Türetme yanlışsa
/// ekran gerçekte olmayan bir şey söyler ve bunu ancak cihazda fark ederiz.
void main() {
  MistakeEntry entry({
    String subject = 'Matematik',
    String concept = 'Türev',
    DateTime? date,
    bool mastered = false,
    bool isLeech = false,
    int lapses = 0,
    int step = 0,
    DateTime? due,
  }) {
    return MistakeEntry(
      subject: subject,
      concept: concept,
      note: '',
      date: date ?? DateTime(2026, 9, 2),
      mastered: mastered,
      isLeech: isLeech,
      lapses: lapses,
      step: step,
      nextReviewDate: due,
    );
  }

  final DateTime now = DateTime(2026, 9, 2, 14, 30);

  group('MistakeStats', () {
    test('boş liste sıfırlanır, yüzde 0 (sıfıra bölme yok)', () {
      final MistakeStats s = MistakeStats.from(<MistakeEntry>[], now: now);
      expect(s.total, 0);
      expect(s.mastered, 0);
      expect(s.learning, 0);
      expect(s.masteredPercent, 0);
      expect(s.leeches, isEmpty);
      expect(s.week, <int>[0, 0, 0, 0, 0, 0, 0]);
      expect(s.weekPeak, 0);
    });

    test('hâkim ve öğrenilen ayrı sayılır, yüzde yuvarlanır', () {
      final MistakeStats s = MistakeStats.from(<MistakeEntry>[
        entry(mastered: true),
        entry(mastered: true),
        entry(),
      ], now: now);
      expect(s.total, 3);
      expect(s.mastered, 2);
      expect(s.learning, 1);
      // 2/3 = %66,67 → 67
      expect(s.masteredPercent, 67);
    });

    test('"bugün" sayısı planlanan güne bakar, adıma değil', () {
      final MistakeStats s = MistakeStats.from(<MistakeEntry>[
        // Bugün eklendi, tekrarı YARIN: adımı 0 ama bugüne ait değil.
        entry(step: 0, due: now.add(const Duration(days: 1))),
        // Planı bugün.
        entry(step: 1, due: now),
        // Planı geçmişte (gecikmiş) — o da bugünün kuyruğunda.
        entry(step: 2, due: now.subtract(const Duration(days: 3))),
        // Hâkim olunan, planı geçmişte olsa bile sayılmaz.
        entry(mastered: true, due: now.subtract(const Duration(days: 3))),
        // Planı bilinmiyor (yerel kayıt) — sayılmaz.
        entry(step: 0),
      ], now: now);
      expect(s.dueToday, 2);
      expect(s.learning, 4);
      expect(s.mastered, 1);
    });

    test('inatçı: is_leech VEYA eşiği geçen lapses', () {
      final MistakeStats s = MistakeStats.from(<MistakeEntry>[
        entry(concept: 'A', isLeech: true, lapses: 1),
        entry(concept: 'B', lapses: 4),
        entry(concept: 'C', lapses: 3),
        entry(concept: 'D', lapses: 9),
      ], now: now);
      expect(s.leeches.length, 3);
      // Çok yanılınandan aza doğru sıralı.
      expect(s.leeches.first.concept, 'D');
      expect(
        s.leeches.map((MistakeEntry e) => e.concept),
        isNot(contains('C')),
        reason: 'lapses 3, eşik 4 — inatçı değil',
      );
    });

    test('eşik zamanlayıcınınkiyle AYNI olmalı', () {
      // Ekrandaki "en az dört kez" metni bu eşitliğe dayanıyor.
      expect(MistakeStats.leechThreshold, const ReviewScheduler().leechThreshold);
      expect(MistakeStats.leechThreshold, schedulerLeechThreshold);
    });

    test('son 7 gün penceresi: bugün sonda, 7 günden eski sayılmaz', () {
      final MistakeStats s = MistakeStats.from(<MistakeEntry>[
        entry(date: now), // bugün
        entry(date: now.subtract(const Duration(days: 1))),
        entry(date: now.subtract(const Duration(days: 1))),
        entry(date: now.subtract(const Duration(days: 6))), // pencerenin ilk günü
        entry(date: now.subtract(const Duration(days: 7))), // DIŞARIDA
        entry(date: now.subtract(const Duration(days: 40))),
      ], now: now);

      expect(s.week.length, 7);
      expect(s.week.last, 1, reason: 'bugün eklenen 1 kayıt');
      expect(s.week[5], 2, reason: 'dün eklenen 2 kayıt');
      expect(s.week.first, 1, reason: '6 gün önce eklenen 1 kayıt');
      expect(s.week.reduce((int a, int b) => a + b), 4,
          reason: '7 ve 40 gün öncekiler pencereye girmez');
      expect(s.weekPeak, 2);
    });

    test('gün etiketleri pencereyle aynı sırada ve bugünle biter', () {
      // 2 Eylül 2026 bir Çarşamba.
      final MistakeStats s = MistakeStats.from(<MistakeEntry>[], now: now);
      expect(s.weekLabels.length, 7);
      expect(s.weekLabels.last, 'Çar');
      expect(s.weekLabels.first, 'Per', reason: '6 gün önce Perşembe');
    });

    test('günün saati pencereyi kaydırmaz (gün başına normalize)', () {
      final MistakeStats geceYarisi = MistakeStats.from(<MistakeEntry>[
        entry(date: DateTime(2026, 9, 2, 0, 1)),
      ], now: DateTime(2026, 9, 2, 23, 59));
      expect(geceYarisi.week.last, 1);
    });

    test('derse göre dağılım çoktan aza sıralı', () {
      final MistakeStats s = MistakeStats.from(<MistakeEntry>[
        entry(subject: 'Fizik'),
        entry(subject: 'Matematik'),
        entry(subject: 'Matematik'),
        entry(subject: 'Matematik'),
        entry(subject: 'Kimya'),
        entry(subject: 'Kimya'),
      ], now: now);
      expect(s.bySubject.keys.toList(), <String>['Matematik', 'Kimya', 'Fizik']);
      expect(s.bySubject['Matematik'], 3);
    });

    test('gelecek tarihli kayıt pencereyi bozmaz', () {
      // Saat farkı ya da bozuk veri yüzünden ileri tarihli bir kayıt gelirse
      // dizi sınırlarının dışına yazmamalı.
      final MistakeStats s = MistakeStats.from(<MistakeEntry>[
        entry(date: now.add(const Duration(days: 3))),
      ], now: now);
      expect(s.week, <int>[0, 0, 0, 0, 0, 0, 0]);
      expect(s.total, 1);
    });
  });
}
