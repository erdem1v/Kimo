import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/notification_lines.dart';
import 'package:kimo/features/onboarding/persona_card.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/models/mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// B8 — SEÇİM EKRANI BİR SÖZ VERİYOR.
///
/// Persona kartındaki örnek cümle, o personayı seçen kullanıcının üründe
/// duyacağı sesi temsil ediyor. Eskiden cümleler ARB'de elle yazılmıştı ve
/// havuzdaki hiçbir satırla tutmuyordu: kurulumda bir ses, bildirimde başka
/// bir ses. Artık kart ÖNCE canlı havuzu okuyor; ARB yedeği ise havuzun 0.
/// varyantının birebir kopyası olmak zorunda — bu testin işi o kopyayı
/// bayatlamaya bırakmamak.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late L10n l;
  setUpAll(() async {
    l = await L10n.delegate.load(const Locale('tr'));
  });

  tearDown(() => notificationLines.resetForTest());

  /// Göçteki `friend_streak` × persona × idx 0 satırları.
  Map<String, String> seedLines() {
    final String sql = File(
      'supabase/migrations/20260904000100_persona_lines.sql',
    ).readAsStringSync();
    final RegExp row = RegExp(r"\('friend_streak','([a-z_]+)',0,'((?:[^']|'')*)'\)");
    final Map<String, String> out = <String, String>{};
    for (final RegExpMatch m in row.allMatches(sql)) {
      out[m.group(1)!] = m.group(2)!.replaceAll("''", "'");
    }
    return out;
  }

  test('ARB yedeği havuzun 0. varyantıyla BİREBİR aynı', () {
    final Map<String, String> seed = seedLines();
    expect(seed.length, 4, reason: 'dört personanın da 0. varyantı bulunmalı');

    for (final Mascot m in Mascot.values) {
      final String? pool = seed[m.dbValue];
      expect(pool, isNotNull, reason: '${m.dbValue} havuzda yok');
      final String expected = NotificationLines.fill(
        pool!,
        ad: l.mascotPreviewFriend,
        n: kPersonaPreviewDays,
      );
      expect(
        personaSample(l, m),
        expected,
        reason: 'kart ${m.dbValue} için üründe DUYULMAYAN bir cümle gösteriyor',
      );
    }
  });

  test('havuz sıcakken kart ARB yedeğini değil havuzu okuyor', () async {
    const String line = '{ad} {n} gündür sahada. Sunucudan gelen cümle.';
    SharedPreferences.setMockInitialValues(<String, Object>{
      'notify.lines_v1': jsonEncode(<String, dynamic>{
        'lines': <String, dynamic>{
          'friend_streak|ceo': <String>[line, 'ikinci varyant'],
        },
        'titles': <String, dynamic>{},
      }),
    });
    notificationLines.resetForTest();
    await notificationLines.load();

    expect(
      personaSample(l, Mascot.ceo),
      NotificationLines.fill(line, ad: l.mascotPreviewFriend, n: kPersonaPreviewDays),
    );
    // Havuzda olmayan personada yedek hâlâ çalışıyor.
    expect(personaSample(l, Mascot.arabeskci), isNotEmpty);
  });
}
