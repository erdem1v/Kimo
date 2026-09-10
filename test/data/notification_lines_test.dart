import 'dart:convert';
import 'dart:math';

import 'package:kimo/data/notification_lines.dart';
import 'package:kimo/models/mascot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bildirim metinlerinin istemci tarafı.
///
/// İki sözleşme kilitleniyor:
///  1. **Ardışık tekrar yok.** Eskiden iki tarafta da hafıza yoktu; beş
///     varyantta aynı cümlenin arka arkaya gelme olasılığı %20'ydi ve aynı
///     cümleyi üst üste gören kullanıcı bildirimi okumayı bırakıyordu.
///  2. **Bildirim asla düşmez.** Havuz inmemişse (yeni kurulum + çevrimdışı)
///     nötr yedek cümle kullanılır — persona duyulmaz ama hatırlatma gider.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String cacheKey = 'notify.lines_v1';
  const String cursorKey = 'notify.last_idx.friend_streak';

  /// Sahte depoyu tazeler ve önbelleği sıfırlar. `setMockInitialValues` tek
  /// başına yetmiyor: `getInstance()` bir örneği önbelleğe alıyor ve `reload()`
  /// olmadan bir önceki testin yazdıkları sızıyor (bkz. app_settings_test).
  Future<void> seed([Map<String, Object> values = const <String, Object>{}]) async {
    SharedPreferences.setMockInitialValues(values);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    notificationLines.resetForTest();
  }

  String cacheWith(List<String> lines) => jsonEncode(<String, dynamic>{
        'lines': <String, dynamic>{'friend_streak|ev_hanimi': lines},
        'titles': <String, dynamic>{'friend_streak': 'Arkadaşın seri yapıyor'},
      });

  group('pickLineIndex', () {
    test('boş havuzda seçilecek satır yok', () {
      expect(pickLineIndex(0, -1, Random(1)), -1);
      expect(pickLineIndex(-3, 2, Random(1)), -1);
    });

    test('tek varyantta tekrar kaçınılmaz — bildirimi düşürmektense tekrarla',
        () {
      expect(pickLineIndex(1, 0, Random(1)), 0);
    });

    test('son gösterilen ASLA tekrar seçilmez', () {
      // Tohum değiştikçe sonuç değişir ama dışlama her tohumda geçerli olmalı.
      for (int seed = 0; seed < 50; seed++) {
        for (int last = 0; last < 5; last++) {
          final int got = pickLineIndex(5, last, Random(seed));
          expect(got, isNot(last), reason: 'seed=$seed last=$last');
          expect(got, inInclusiveRange(0, 4));
        }
      }
    });

    test('iki varyantta seçim tamamen belirli', () {
      expect(pickLineIndex(2, 0, Random(7)), 1);
      expect(pickLineIndex(2, 1, Random(7)), 0);
    });

    test('imleç aralık dışıysa (havuz küçüldü) tüm satırlar aday', () {
      final Set<int> seen = <int>{};
      for (int seed = 0; seed < 40; seed++) {
        seen.add(pickLineIndex(3, 9, Random(seed)));
      }
      expect(seen, containsAll(<int>[0, 1, 2]));
    });
  });

  group('önbellek', () {

    test('diskteki havuzdan okur, yer tutucuları doldurur', () async {
      await seed(<String, Object>{
        cacheKey: cacheWith(<String>['{ad} {n} gündür aksatmıyor.']),
      });
      await notificationLines.load();

      expect(notificationLines.isReady, isTrue);
      expect(notificationLines.title(NotifyKind.friendStreak),
          'Arkadaşın seri yapıyor');
      final String body = await notificationLines
          .pick(NotifyKind.friendStreak, Mascot.evHanimi, ad: 'Elif', n: 12);
      expect(body, 'Elif 12 gündür aksatmıyor.');
    });

    test('seçilen satır imlece yazılır ve bir sonrakinde dışlanır', () async {
      await seed(<String, Object>{
        cacheKey: cacheWith(<String>['birinci', 'ikinci']),
        cursorKey: 0,
      });
      await notificationLines.load();

      // İmleç 0'da: iki varyantlı havuzda tek seçenek 'ikinci'.
      expect(
        await notificationLines.pick(NotifyKind.friendStreak, Mascot.evHanimi),
        'ikinci',
      );
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(cursorKey), 1);

      // İmleç şimdi 1: sıradaki seçim 'birinci' olmak zorunda.
      expect(
        await notificationLines.pick(NotifyKind.friendStreak, Mascot.evHanimi),
        'birinci',
      );
      expect(prefs.getInt(cursorKey), 0);
    });

    test('havuz boşken nötr yedeğe düşer — bildirim yine de gider', () async {
      await seed();
      await notificationLines.load();

      expect(notificationLines.isReady, isFalse);
      final String body = await notificationLines
          .pick(NotifyKind.reviewsDue, Mascot.ceo, n: 5);
      expect(body, isNotEmpty);
      expect(body, contains('5'));
      // Yedek metin yer tutucu SIZDIRMAMALI.
      expect(body, isNot(contains('{')));
      expect(notificationLines.title(NotifyKind.reviewsDue), isNotEmpty);
    });

    test('bozuk önbellek uygulamayı düşürmez, yedeğe düşer', () async {
      await seed(<String, Object>{cacheKey: 'bu JSON değil'});
      await notificationLines.load();

      expect(notificationLines.isReady, isFalse);
      final String body = await notificationLines
          .pick(NotifyKind.comeback, Mascot.sanayiUstasi);
      expect(body, isNotEmpty);
    });

    test('önizleme imleci OYNATMAZ', () async {
      await seed(<String, Object>{
        cacheKey: cacheWith(<String>['birinci', 'ikinci']),
      });
      await notificationLines.load();

      expect(
        notificationLines.preview(NotifyKind.friendStreak, Mascot.evHanimi, 1),
        'ikinci',
      );
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(cursorKey), isNull);
      // Aralık dışı önizleme sessizce null döner (havuz küçülmüş olabilir).
      expect(
        notificationLines.preview(NotifyKind.friendStreak, Mascot.evHanimi, 9),
        isNull,
      );
    });
  });

  group('anahtar yazımı', () {
    test('payload anahtarları sunucudaki push_kinds ile birebir aynı', () {
      // Bu liste 0055 göçündeki `push_kinds` satırlarının aynısı. Ayrışırsa
      // bildirim ya hiç gitmez ya da dokunulduğunda yanlış ekrana götürür.
      expect(
        NotifyKind.values.map((NotifyKind k) => k.payload).toSet(),
        <String>{
          'reviews_due',
          'streak_risk',
          'comeback',
          'league_last_day',
          'league_result',
          'question_received',
          'friend_request',
          'question_solved',
          'friend_league_up',
          'friend_streak',
        },
      );
    });

    test('persona anahtarları sunucudaki CHECK kısıtıyla aynı', () {
      expect(
        Mascot.values.map((Mascot m) => m.dbValue).toList(),
        <String>['ev_hanimi', 'arabeskci', 'sanayi_ustasi', 'ceo'],
      );
      // Akademisyen kaldırıldı; göç mevcut kullanıcıları varsayılana eşliyor.
      expect(Mascot.fromDb('akademisyen'), isNull);
      expect(Mascot.fallback.dbValue, 'ev_hanimi');
    });
  });
}
