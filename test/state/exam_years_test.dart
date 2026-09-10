import 'package:ai_yks_coach/features/reviews/domain/review_scheduler.dart';
import 'package:ai_yks_coach/state/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seçilebilir sınav yılları.
///
/// Neden test edilmesi gerekiyor: liste Task 08'e kadar iki dosyada
/// `[2026 … 2030]` sabitiydi. Sabit liste sessizce bayatlıyor — geçmiş bir yıl
/// listenin başında durmaya, ileri bir yıla hazırlanan öğrenci de hiçbir yıl
/// bulamamaya başlıyor. Türetme yanlışsa aynı sessizlik geri gelir; tek fark,
/// bu kez yanlış olan bir hesap olur.
void main() {
  group('UserProfile.examYears', () {
    test('sınav gününden ÖNCE bu yıldan başlar', () {
      // 2026 sınavı 20 Haziran'da; 19 Haziran'da hâlâ 2026'ya hazırlanılıyor.
      final List<int> years =
          UserProfile.examYears(now: DateTime(2026, 6, 19));
      expect(years.first, 2026);
      expect(years, <int>[2026, 2027, 2028, 2029, 2030]);
    });

    test('sınav gününde HÂLÂ bu yıl (kesme dahil)', () {
      // Sınav tarihi `examCutoffFor` ile aynı gün; o gün "geçmiş" sayılmıyor.
      expect(UserProfile.examYears(now: DateTime(2026, 6, 20)).first, 2026);
    });

    test('sınav geçtikten sonra ertesi yıldan başlar', () {
      final List<int> years =
          UserProfile.examYears(now: DateTime(2026, 6, 21));
      expect(years.first, 2027);
      expect(years, <int>[2027, 2028, 2029, 2030, 2031]);
    });

    test('yıl ilerledikçe liste kendiliğinden kayar (bayatlamıyor)', () {
      expect(UserProfile.examYears(now: DateTime(2031, 1, 5)).first, 2031);
      expect(UserProfile.examYears(now: DateTime(2040, 12, 31)).first, 2041);
    });

    test('uzunluk sabit ve ardışık', () {
      final List<int> years =
          UserProfile.examYears(now: DateTime(2027, 3, 1));
      expect(years.length, UserProfile.examYearCount);
      for (int i = 1; i < years.length; i++) {
        expect(years[i], years[i - 1] + 1);
      }
    });

    test('sınav tarihi TEK KAYNAKTAN geliyor', () {
      // Liste `ReviewScheduler.examCutoffFor` ile aynı tarihi kullanıyor;
      // ikisi ayrışırsa "sınavım geçti mi" sorusuna iki farklı cevap çıkardı.
      final DateTime cutoff = ReviewScheduler.examCutoffFor(2026)!;
      expect(cutoff, DateTime(2026, 6, 20));
      expect(
        UserProfile.examYears(now: cutoff.add(const Duration(days: 1))).first,
        2027,
      );
      expect(
        UserProfile.examYears(now: cutoff.subtract(const Duration(days: 1)))
            .first,
        2026,
      );
    });

    test('müfredat eşiğiyle uyumlu: 2028 ve sonrası maarif', () {
      // Liste 2026'da başlıyorsa hem eski hem maarif yılları içeriyor; eşik
      // `curriculumForYear` içinde ve liste onu kırmamalı.
      final List<int> years =
          UserProfile.examYears(now: DateTime(2026, 1, 1));
      expect(UserProfile.curriculumForYear(years.first), UserProfile.eski);
      expect(UserProfile.curriculumForYear(2028), UserProfile.maarif);
    });
  });
}
