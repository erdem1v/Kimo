import 'package:ai_yks_coach/state/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Sahte depoyu tazeler. `setMockInitialValues` tek başına yetmiyor:
  /// `SharedPreferences.getInstance()` bir örneği önbelleğe alıyor ve o örnek
  /// değerleri kendi belleğinde tutuyor; `reload()` olmadan bir önceki testin
  /// yazdıkları sızıyor.
  Future<void> resetPrefs([Map<String, Object> values = const <String, Object>{}]) async {
    SharedPreferences.setMockInitialValues(values);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  }

  setUp(() async {
    await resetPrefs();
  });

  group('tema modu', () {
    test('varsayılan SİSTEM: kullanıcı seçim yapana kadar cihazı takip eder',
        () async {
      await appSettings.load();
      expect(appSettings.themeMode, ThemeMode.system);
    });

    test('seçim diske yazılır ve yeniden okunur', () async {
      await appSettings.load();
      await appSettings.setThemeMode(ThemeMode.dark);
      expect(appSettings.themeMode, ThemeMode.dark);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings.theme_mode'), 'dark');

      await appSettings.load();
      expect(appSettings.themeMode, ThemeMode.dark);
    });

    test('bozuk değer sisteme düşer', () async {
      await resetPrefs(<String, Object>{'settings.theme_mode': 'mor'});
      await appSettings.load();
      expect(appSettings.themeMode, ThemeMode.system);
    });

    test('değişiklik dinleyicileri uyarır', () async {
      await appSettings.load();
      int calls = 0;
      void listener() => calls++;
      appSettings.addListener(listener);
      addTearDown(() => appSettings.removeListener(listener));

      await appSettings.setThemeMode(ThemeMode.light);
      expect(calls, 1);

      // Aynı değeri yeniden atamak gereksiz yeniden çizim üretmemeli.
      await appSettings.setThemeMode(ThemeMode.light);
      expect(calls, 1);
    });
  });

  group('ses tercihi', () {
    test('varsayılan açık ve diske yazılır', () async {
      await appSettings.load();
      expect(appSettings.soundEnabled, isTrue);

      await appSettings.setSoundEnabled(false);
      await appSettings.load();
      expect(appSettings.soundEnabled, isFalse,
          reason: 'ses tercihi artık her açılışta sıfırlanmıyor');
    });
  });

  group('sessiz aralık', () {
    test('gece yarısını aşan aralık doğru hesaplanır (22:00–08:00)', () async {
      await appSettings.load();
      await appSettings.setQuietRange(22, 8);

      expect(appSettings.isQuietHour(23), isTrue);
      expect(appSettings.isQuietHour(0), isTrue);
      expect(appSettings.isQuietHour(7), isTrue);
      expect(appSettings.isQuietHour(8), isFalse, reason: 'bitiş saati hariç');
      expect(appSettings.isQuietHour(21), isFalse);
      expect(appSettings.isQuietHour(22), isTrue, reason: 'başlangıç dâhil');
    });

    test('gün içinde kalan aralık (13:00–15:00)', () async {
      await appSettings.load();
      await appSettings.setQuietRange(13, 15);

      expect(appSettings.isQuietHour(12), isFalse);
      expect(appSettings.isQuietHour(13), isTrue);
      expect(appSettings.isQuietHour(14), isTrue);
      expect(appSettings.isQuietHour(15), isFalse);
      expect(appSettings.isQuietHour(23), isFalse);
    });

    test('başlangıç ile bitiş aynıysa sessiz saat YOKTUR', () async {
      await appSettings.load();
      await appSettings.setQuietRange(9, 9);
      for (int h = 0; h < 24; h++) {
        expect(appSettings.isQuietHour(h), isFalse, reason: '$h. saat');
      }
    });
  });

  group('hatırlatma saatleri', () {
    test('varsayılanlar koddaki eski sabit saatlerle aynı', () async {
      await appSettings.load();
      expect(appSettings.reviewHour, 17);
      expect(appSettings.streakHour, 20);
      expect(appSettings.quietStart, 22);
      expect(appSettings.quietEnd, 8);
    });

    test('aralık dışı saat varsayılana düşer', () async {
      await appSettings.load();
      await appSettings.setReviewHour(31);
      expect(appSettings.reviewHour, AppSettings.defaultReviewHour);

      await appSettings.setStreakHour(-3);
      expect(appSettings.streakHour, AppSettings.defaultStreakHour);
    });

    test('geçerli saat kabul edilir ve kalıcıdır', () async {
      await appSettings.load();
      await appSettings.setReviewHour(9);
      await appSettings.load();
      expect(appSettings.reviewHour, 9);
    });
  });
}
