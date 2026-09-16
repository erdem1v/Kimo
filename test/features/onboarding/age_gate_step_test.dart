import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/daily_state_repository.dart';
import 'package:kimo/features/onboarding/age_gate_step.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:kimo/widgets/kit/kimo_button.dart';

/// Yaş adımının Task 15'te kapatılan iki kusuru.
///
/// Kaydetme yolu sunucuya gidiyor ve burada kapsam dışı; sınanan şey adımın
/// İKİ HÂLİNİN nasıl çizildiği.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late L10n l;

  setUpAll(() async {
    l = await L10n.delegate.load(const Locale('tr'));
  });

  Future<void> pumpStep(WidgetTester tester, AgeStatus? status) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: Scaffold(
        body: AgeGateStep(
          status: status,
          onChanged: () async {},
          onDone: () async {},
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('açılışta bir yıl seçili: "Kaydet" HEMEN etkin',
      (WidgetTester tester) async {
    // K4 + B3. `_year` eskiden null başlıyordu ve `onSelectedItemChanged`
    // yalnızca KAYDIRMADA ateşlendiği için düğme ancak çark çevrilince
    // açılıyordu — kullanıcıya ne yapması gerektiğini söyleyen hiçbir işaret
    // yoktu. Değer artık `initState`te veriliyor, `build` içinde değil.
    await pumpStep(tester, const AgeStatus(birthYearSet: false, isMinor: false));
    final KimoButton save = tester
        .widget<KimoButton>(find.widgetWithText(KimoButton, l.actionSave));
    expect(save.onPressed, isNotNull);
  });

  testWidgets('yeniden çizim çarkın seçimini BOZMUYOR',
      (WidgetTester tester) async {
    // Denetleyici `build` içinde üretiliyordu: her karede yenisi doğuyor,
    // hiçbiri atılmıyordu. Artık `initState`te kurulup `dispose`ta kapanıyor.
    await pumpStep(tester, const AgeStatus(birthYearSet: false, isMinor: false));
    final int expected = DateTime.now().year -
        ((DateTime.now().year - 1990 + 1) / 2).floor();
    expect(find.text('$expected'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('$expected'), findsWidgets);
  });

  testWidgets('yıl kayıtlıysa DEĞERİ gösteriliyor, çark ve Kaydet yok',
      (WidgetTester tester) async {
    // B2. Bu hâl artık yalnızca GERİ DÖNÜLDÜĞÜNDE görünüyor (kayıt başarılı
    // olunca adım kendiliğinden ilerliyor) ve kaydedilen yılı geri gösteriyor.
    // Eskiden adımın normal hâliydi: ekranın ortası boş, yalnızca "bir kez
    // yazılır" notunu tekrarlayan yeşil bir rozet ve ikinci bir "Devam et".
    await pumpStep(
      tester,
      const AgeStatus(birthYearSet: true, isMinor: false, birthYear: 2008),
    );
    expect(find.text(l.ageSavedNote('2008')), findsOneWidget);
    expect(find.widgetWithText(KimoButton, l.actionSave), findsNothing);
  });
}
