import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/features/league/friend_request_tile.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/models/social.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:kimo/theme/tokens.dart';
import 'package:kimo/widgets/kit/kimo_button.dart';

/// Gelen arkadaşlık isteği satırı (Task 18 turu).
///
/// Üç düğme tek sırada eşit bölüşünce "Kabul et" 393pt'te iki satıra
/// kırılıyordu. Sabitlenen: 375pt (SE) ve 393pt genişlikte üç etiket de TEK
/// satır; `busy` üçünü de kilitler; her düğme kendi geri çağrısını tetikler.
void main() {
  late L10n l;
  setUpAll(() async {
    l = await L10n.delegate.load(const Locale('tr'));
    // GERÇEK YAZI TİPLERİ. `flutter_test` varsayılanı Ahem: her harf, punto
    // kadar geniş bir kare. Onunla "Reddet" 375pt'te bile taşıyor ve test
    // gerçek cihazda olmayan bir kırılmayı raporluyordu. Uygulamanın kendi
    // dosyaları yükleniyor; ölçüm cihazdakiyle aynı metriklerde.
    for (final (String family, List<int> weights) in <(String, List<int>)>[
      ('Baloo2', <int>[500, 600, 700]),
      ('DMSans', <int>[400, 500, 600, 700]),
    ]) {
      final FontLoader loader = FontLoader(family);
      for (final int w in weights) {
        final Uint8List bytes =
            File('assets/fonts/$family-$w.ttf').readAsBytesSync();
        loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    }
  });

  const PublicProfile bora =
      PublicProfile(id: 'u2', nickname: 'Bora', xp: 10, streak: 1);

  Future<void> pump(
    WidgetTester tester, {
    required double width,
    bool busy = false,
    VoidCallback? onAccept,
    VoidCallback? onDecline,
    VoidCallback? onBlock,
  }) async {
    tester.view.physicalSize = Size(width * 3, 812 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: Scaffold(
        body: Padding(
          // FriendsView'ın liste dolgusu: satır gerçek genişliğinde ölçülsün.
          padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
          child: FriendRequestTile(
            profile: bora,
            mutual: 2,
            busy: busy,
            onAccept: onAccept ?? () {},
            onDecline: onDecline ?? () {},
            onBlock: onBlock ?? () {},
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  /// Tek satır ölçütü: etiket, satırın SIĞMAK ZORUNDA OLMADIĞI 1000pt
  /// genişlikteki yüksekliğiyle aynı. Kırılan etiket bunun en az iki katı olur
  /// (sabit bir sayı değil; `KimoButton`un satır yüksekliği tema kararı).
  for (final double w in <double>[375, 393]) {
    testWidgets('${w.toInt()}pt: üç etiket tek satır, ortak arkadaş yazılı',
        (WidgetTester tester) async {
      final List<String> labels = <String>[
        l.friendsAccept,
        l.friendsDecline,
        l.friendsBlock,
      ];
      await pump(tester, width: 1000);
      final Map<String, double> oneLine = <String, double>{
        for (final String s in labels) s: tester.getSize(find.text(s)).height,
      };

      await pump(tester, width: w);
      for (final String s in labels) {
        expect(tester.getSize(find.text(s)).height, oneLine[s],
            reason: '"$s" ${w.toInt()}pt genişlikte kırıldı');
      }
      expect(find.text(l.friendsMutual(2)), findsOneWidget);
    });
  }

  testWidgets('busy: üç düğme de kapalı', (WidgetTester tester) async {
    await pump(tester, width: 393, busy: true);
    for (final String label in <String>[
      l.friendsAccept,
      l.friendsDecline,
      l.friendsBlock,
    ]) {
      final KimoButton b =
          tester.widget<KimoButton>(find.widgetWithText(KimoButton, label));
      expect(b.onPressed, isNull, reason: label);
    }
  });

  testWidgets('her düğme kendi geri çağrısını tetikler',
      (WidgetTester tester) async {
    int accept = 0, decline = 0, block = 0;
    await pump(
      tester,
      width: 393,
      onAccept: () => accept++,
      onDecline: () => decline++,
      onBlock: () => block++,
    );
    await tester.tap(find.text(l.friendsAccept));
    await tester.tap(find.text(l.friendsDecline));
    await tester.tap(find.text(l.friendsBlock));
    await tester.pump();
    expect((accept, decline, block), (1, 1, 1));
  });
}
