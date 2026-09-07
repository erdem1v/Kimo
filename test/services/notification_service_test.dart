import 'package:ai_yks_coach/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sessiz saat kaydırıcısının sözleşmesi: aralığa denk gelen hatırlatma
/// DÜŞMEZ, bir sonraki uygun saate KAYAR — ayarlardaki metnin söylediği bu
/// (eski kod düşürüyordu; Task 03).
void main() {
  bool quiet22to08(int h) => h >= 22 || h < 8;

  test('servis tekili kuruludur (import canlı — sembol denetçisi için)', () {
    expect(notifications, isA<NotificationService>());
  });

  group('resolveScheduledHour', () {
    test('sessiz olmayan saat olduğu gibi geçer', () {
      final ({int hour, int addDays})? r =
          resolveScheduledHour(17, quiet22to08);
      expect(r, isNotNull);
      expect(r!.hour, 17);
      expect(r.addDays, 0);
    });

    test('sessiz aralıktaki saat aralığın sonuna kayar (gece yarısını aşar)',
        () {
      // 23:00 → 22-08 sessiz → ertesi gün 08:00.
      final ({int hour, int addDays})? r =
          resolveScheduledHour(23, quiet22to08);
      expect(r!.hour, 8);
      expect(r.addDays, 1);
    });

    test('gece yarısından sonraki sessiz saat AYNI GÜN içinde kayar', () {
      // 03:00 → 08:00, gün değişmez.
      final ({int hour, int addDays})? r =
          resolveScheduledHour(3, quiet22to08);
      expect(r!.hour, 8);
      expect(r.addDays, 0);
    });

    test('sessiz aralığın tam başlangıcı da kayar', () {
      final ({int hour, int addDays})? r =
          resolveScheduledHour(22, quiet22to08);
      expect(r!.hour, 8);
      expect(r.addDays, 1);
    });

    test('24 saatin tamamı sessizse null döner (hiç planlanmaz)', () {
      expect(resolveScheduledHour(12, (_) => true), isNull);
    });

    test('taşan saat değeri normalize edilir', () {
      final ({int hour, int addDays})? r =
          resolveScheduledHour(41, quiet22to08); // 41 % 24 = 17
      expect(r!.hour, 17);
    });
  });
}
