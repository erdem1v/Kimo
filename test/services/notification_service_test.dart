import 'package:kimo/services/notification_service.dart';
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


  // ==========================================================================
  // Task 12 · P6 — ortak seri AKŞAM HATIRLATMASINA katılıyor
  // ==========================================================================
  group('riskReminderCount', () {
    test('ortak seri yoksa kişisel seri yazılıyor', () {
      expect(riskReminderCount(12, 0), 12);
    });

    test('ortak seri daha uzunsa O yazılıyor', () {
      expect(riskReminderCount(3, 9), 9);
    });

    test('kişisel seri daha uzunsa o yazılıyor', () {
      expect(riskReminderCount(20, 6), 20);
    });

    test('ikisi de yoksa hatırlatma HİÇ kurulmuyor (0)', () {
      // `planDay` 0'da bildirimi hiç planlamıyor: "serin tehlikede" demek
      // için bir seri gerekiyor.
      expect(riskReminderCount(0, 0), 0);
    });

    test('İKİ SAYI BİRDEN söylenmiyor — tek sayı dönüyor', () {
      // "12 günlük serin VE 6 günlük ortak serin tehlikede" cümlesi
      // kullanıcıya kaybedecek iki şeyi olduğunu söylerdi. DSA Md. 28(1)
      // Kılavuzu (par. 61(b)) kıtlık/aciliyet sinyallerini ismen sayıyor.
      final int n = riskReminderCount(12, 6);
      expect(n, 12);
      expect(n, isNot(18), reason: 'toplanmıyor');
    });
  });
}
