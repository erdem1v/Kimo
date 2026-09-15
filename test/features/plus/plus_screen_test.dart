import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/features/plus/plus_plans.dart';
import 'package:kimo/features/plus/plus_screen.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:kimo/widgets/kit/kimo_button.dart';

/// Paywall (w3). Satın alma BU TASK'TA YOK; ekranın dürüst durması sınanıyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late L10n l;

  setUpAll(() async {
    l = await L10n.delegate.load(const Locale('tr'));
  });

  Future<void> pumpPlus(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: const PlusScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 32));
  }

  testWidgets('CTA var ama DEVRE DIŞI ve nedeni yazıyor',
      (WidgetTester tester) async {
    await pumpPlus(tester);
    final KimoButton cta = tester.widget<KimoButton>(
        find.widgetWithText(KimoButton, l.plusCta(PlusPlans.trialDays)));
    // `onPressed: null` mekanizmanın tamamı. Hiçbir şey yapmayan bir düğme,
    // kullanıcının dokunarak keşfettiği bir yalan olurdu.
    expect(cta.onPressed, isNull);
    expect(find.text(l.plusNotAvailableYet), findsOneWidget);
  });

  testWidgets('"geri yükle" ve "aboneliği yönet" HİÇ ÇİZİLMİYOR',
      (WidgetTester tester) async {
    // Hiçbir şeyi geri yüklemeyen bir "geri yükle" satırı kanonik bir App
    // Store reddi. `legal_links.dart` aynı kararı belgeliyor.
    await pumpPlus(tester);
    expect(find.text(l.plusRestore), findsNothing);
    expect(find.text(l.plusManage), findsNothing);
  });

  testWidgets('kıyas tablosu üç satır, rakamlar görünüyor',
      (WidgetTester tester) async {
    await pumpPlus(tester);
    expect(find.text(l.plusColFree), findsOneWidget);
    expect(find.text(l.plusColPlus), findsOneWidget);
    expect(find.text(l.plusAnalyses(10)), findsOneWidget);
    expect(find.text(l.plusAnalyses(50)), findsOneWidget);
    expect(find.text('300'), findsOneWidget);
    expect(find.text('1000'), findsOneWidget);
    expect(find.text(l.plusExtraFree), findsOneWidget);
    expect(find.text(l.plusExtraPlus), findsOneWidget);
  });

  testWidgets('yıllık plan varsayılan seçili ve avantaj rozeti onda',
      (WidgetTester tester) async {
    await pumpPlus(tester);
    // Sayfa Task 12'de çoklu çekim bölümüyle uzadı (Tur 7 · n4) ve planlar
    // katlamanın altına indi; `ListView` tembel kurduğu için rozet ancak
    // kaydırıldıktan sonra ağaçta oluyor.
    await tester.scrollUntilVisible(
      find.text(l.plusSaveBadge(33)),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(l.plusSaveBadge(33)), findsOneWidget);
    expect(PlusPlans.defaultPlan.savingPercent, 33);
  });

  testWidgets('çoklu çekim bölümü rakam söylüyor, abartı söylemiyor',
      (WidgetTester tester) async {
    await pumpPlus(tester);
    expect(find.text(l.plusBatchTitle), findsOneWidget);
    // Üç madde de RAKAM taşıyor: kaç fotoğraf, hangi giriş, kaç analiz.
    expect(find.text(l.plusBatchPhotos(10)), findsOneWidget);
    expect(find.text(l.plusBatchGallery), findsOneWidget);
    // TAAHHÜT: tekli çekim ücretsizde tam çalışmaya devam ediyor.
    expect(find.text(l.plusBatchSingleFree), findsOneWidget);
  });

  testWidgets('"sınırsız" HİÇBİR YERDE geçmiyor', (WidgetTester tester) async {
    // Plus'ın da tavanı var (8 saatte 50, ayda 1.000). Rakam söyleniyor,
    // abartı söylenmiyor. CI'da ayrıca bir ARB kapısı var; bu iddia
    // çizilen ekranı da kapsıyor.
    await pumpPlus(tester);
    expect(find.textContaining('ınırsız'), findsNothing);
    expect(find.textContaining('INIRSIZ'), findsNothing);
  });

  testWidgets('AI koç ve rapor listede YOK (v1''de yok)',
      (WidgetTester tester) async {
    await pumpPlus(tester);
    expect(find.textContaining('koç'), findsNothing);
    expect(find.textContaining('Rapor'), findsNothing);
  });

  test('fiyatlar TEK dosyada ve yer tutucu olduğu beyan edilmiş', () {
    expect(PlusPlans.isConfigured, isFalse);
    expect(PlusPlans.current.length, 2);
    expect(PlusPlans.current.first.priceLabel, contains('₺'));
  });
}
