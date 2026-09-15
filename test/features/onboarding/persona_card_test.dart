import 'package:kimo/data/notification_lines.dart';
import 'package:kimo/features/onboarding/persona_card.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/models/mascot.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:kimo/theme/tokens.dart';
import 'package:kimo/widgets/kimo/kimo.dart';
import 'package:kimo/widgets/kit/kimo_progress.dart';
import 'package:kimo/widgets/kit/kimo_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persona seçim ekranının parçaları.
///
/// Akışın tamamı yerine parçalar pompalanıyor: `OnboardingFlow` açılışta
/// oturum durumu ve veli onayı için ağa gidiyor, persona adımına ulaşmak için
/// önce takma ad ve sınav yılı doldurmak gerekiyor. Bu ekranın sözleşmesi o
/// kurulumdan bağımsız ve burada doğrudan sınanabiliyor.
///
/// **`pumpAndSettle` KULLANILMIYOR:** önizlemedeki Kimo'nun boşta animasyonu
/// (nefes, göz kırpma) hiç bitmiyor, `pumpAndSettle` asla dönmez.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    notificationLines.resetForTest();
  });

  Future<void> pumpIn(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ));
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 32));
  }

  group('PersonaCard', () {
    testWidgets('dört ses de ad ve örnek cümleyle görünür', (WidgetTester tester) async {
      Mascot? tapped;
      await pumpIn(
        tester,
        Column(
          children: <Widget>[
            for (final Mascot m in Mascot.values)
              PersonaCard(
                mascot: m,
                selected: m == Mascot.evHanimi,
                onTap: () => tapped = m,
              ),
          ],
        ),
      );

      expect(find.byType(PersonaCard), findsNWidgets(4));
      // Ekranın tek işi tonların farkını duyurmak: her kartta örnek cümle var.
      // Dördü de aynı senaryodan (friend_streak) konuşuyor, o yüzden hepsinde
      // kurgusal arkadaşın adı geçiyor.
      expect(find.textContaining('Elif'), findsNWidgets(4));

      await tester.tap(find.byType(PersonaCard).last);
      await tester.pump(const Duration(milliseconds: 32));
      expect(tapped, Mascot.ceo);
    });

    testWidgets('dört kart DÖRT FARKLI aksesuar çiziyor (Tur 7 · n3)',
        (WidgetTester tester) async {
      // n3'ün bütün noktası bu: eskiden dördü de AYNI görünüyordu ve kart
      // yalnızca ad + cümleyle ayrışıyordu. Aksesuar üçüncü sinyal.
      await pumpIn(
        tester,
        Column(
          children: <Widget>[
            for (final Mascot m in Mascot.values)
              PersonaCard(mascot: m, selected: false, onTap: () {}),
          ],
        ),
      );
      final List<KimoAccessory?> seen = tester
          .widgetList<Kimo>(find.descendant(
            of: find.byType(PersonaCard),
            matching: find.byType(Kimo),
          ))
          .map((Kimo k) => k.accessory)
          .toList();
      expect(seen.length, 4);
      expect(seen.toSet().length, 4, reason: 'iki kart aynı aksesuarı gösteriyor');
      expect(seen, isNot(contains(null)),
          reason: 'varsayılana düşen kart seçili personayı gösterirdi');
      expect(seen, isNot(contains(KimoAccessory.none)));
    });

    testWidgets('seçili kart aksan zeminiyle ayrışır', (WidgetTester tester) async {
      await pumpIn(
        tester,
        Column(
          children: <Widget>[
            for (final Mascot m in Mascot.values)
              PersonaCard(
                mascot: m,
                selected: m == Mascot.sanayiUstasi,
                onTap: () {},
              ),
          ],
        ),
      );

      final BuildContext ctx = tester.element(find.byType(PersonaCard).first);
      final KimoColors c = ctx.c;
      List<Color?> cardColors() => tester
          .widgetList<KimoCard>(find.descendant(
            of: find.byType(PersonaCard),
            matching: find.byType(KimoCard),
          ))
          .map((KimoCard k) => k.color)
          .toList();

      // Sanayi ustası üçüncü sırada: yalnız o aksan zeminli olmalı.
      expect(cardColors(), <Color?>[c.card, c.card, c.actionTint, c.card]);
    });

    testWidgets('seçim erişilebilirlik ağacına da yansır', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpIn(
        tester,
        PersonaCard(
          mascot: Mascot.arabeskci,
          selected: true,
          onTap: () {},
        ),
      );
      // Renk tek taşıyıcı değil: ekran okuyucu da seçimi bildirir.
      //
      // `hasFlag(SemanticsFlag.…)` Flutter 3.32'de kullanımdan kaldırıldı ve
      // `flutter analyze` bunu `info` olarak bildiriyor — o da CI'daki analyze
      // adımını KIRMIZIYA döndürüyordu (Task 08 kapsamı dışında bulundu,
      // düzeltildi). Yerine `isSemantics`: yalnızca ilgilendiğimiz
      // özelliği iddia ediyor, `matchesSemantics` gibi tüm alanları değil.
      expect(
        tester.getSemantics(find.byType(PersonaCard)),
        isSemantics(isSelected: true),
      );
      handle.dispose();
    });
  });

  group('PersonaPreview', () {
    testWidgets('havuz soğukken karttaki örneğe düşer, boş kalmaz',
        (WidgetTester tester) async {
      await pumpIn(tester, const PersonaPreview(mascot: Mascot.evHanimi));

      expect(notificationLines.isReady, isFalse);
      // Kilit ekranı önizlemesi: gönderen her zaman Kimo, metin dolu.
      expect(find.text('Kimo'), findsOneWidget);
      expect(find.textContaining('Elif'), findsOneWidget);
    });
  });

  group('StepDots', () {
    testWidgets('adım sayısı kadar parça çizer', (WidgetTester tester) async {
      await pumpIn(tester, const StepDots(total: 5, current: 4));
      expect(
        find.descendant(
          of: find.byType(StepDots),
          matching: find.byType(AnimatedContainer),
        ),
        findsNWidgets(5),
      );
    });

    testWidgets('adım yoksa hiç çizmez', (WidgetTester tester) async {
      await pumpIn(tester, const StepDots(total: 0, current: 0));
      expect(
        find.descendant(
          of: find.byType(StepDots),
          matching: find.byType(AnimatedContainer),
        ),
        findsNothing,
      );
    });
  });
}
