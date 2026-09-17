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

  Future<void> pumpPlus(
    WidgetTester tester, {
    bool iapEnabled = true,
    String? subStatus,
    DateTime? subExpiresAt,
    bool subRenews = false,
  }) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      // RAKAMLAR ARTIK ZORUNLU PARAMETRE: `?? 8/10/300/50/1000` yedeği
      // kaldırıldı. Paywall bir RAKAM VAADİ taşıyor ve `app_config`
      // sınırları gevşetildiğinde eski sayıyı göstermesi kabul edilemezdi.
      home: PlusScreen(
        iapEnabled: iapEnabled,
        freeWindowLimit: 10,
        freeMonthLimit: 300,
        plusWindowLimit: 50,
        plusMonthLimit: 1000,
        windowHours: 8,
        subStatus: subStatus,
        subExpiresAt: subExpiresAt,
        subRenews: subRenews,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 32));
  }

  testWidgets('CTA var ama DEVRE DIŞI ve nedeni yazıyor',
      (WidgetTester tester) async {
    PlusPlans.resetForTest();
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
    PlusPlans.resetForTest();
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

  testWidgets('MAĞAZA YANITI YOKSA plan kartı ve rozet HİÇ çizilmiyor',
      (WidgetTester tester) async {
    // Task 13'e kadar planlar koddaki yer tutucu listeden geliyordu ve sabit
    // TL fiyatlarıyla ÇİZİLİYORLARDI — Apple 3.1.2 açısından yayın engeli.
    PlusPlans.resetForTest();
    await pumpPlus(tester);
    expect(find.text(l.plusSaveBadge(33)), findsNothing);
    expect(find.text(l.plusPlanYearly), findsNothing);
    expect(find.text(l.plusPlanMonthly), findsNothing);
  });

  testWidgets('mağaza yanıtı gelince yıllık varsayılan seçili, rozet onda',
      (WidgetTester tester) async {
    // Fiyatlar MAĞAZANIN metni; test onları temsilî veriyor.
    PlusPlans.setProducts(<PlusPlan>[
      const PlusPlan(
          id: PlusPlans.yearlyId,
          priceLabel: 'YILLIK-FİYAT',
          perMonthLabel: 'AYLIK-KARŞILIK',
          savingPercent: 33),
      const PlusPlan(
          id: PlusPlans.monthlyId,
          priceLabel: 'AYLIK-FİYAT',
          perMonthLabel: 'AYLIK-FİYAT'),
    ]);
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
    expect(PlusPlans.defaultPlan?.savingPercent, 33);
    PlusPlans.resetForTest();
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

  test('MAĞAZA YANITI YOKSA hiçbir plan ve hiçbir fiyat yok', () {
    // Task 13'e kadar bu dosya `1.200`/`150` TL yer tutucularını TAŞIYORDU ve
    // onları hem paywall'da hem hak duvarında CANLI çizdiriyordu. Apple 3.1.2
    // ve Play abonelik politikası gösterilen fiyatın kullanıcının mağazasının
    // kendi yerelleştirilmiş fiyatı olmasını şart koşuyor — yani bu bir yayın
    // engeliydi ve mağaza eklentisi gelmeden de kapandı.
    PlusPlans.resetForTest();
    expect(PlusPlans.isConfigured, isFalse);
    expect(PlusPlans.current, isEmpty);
    expect(PlusPlans.defaultPlan, isNull);
  });

  test('mağaza yanıtı geldiğinde sıra korunuyor ve satın alma açılıyor', () {
    // SIRA TASARIM KARARI: yıllık önce ("%33 AVANTAJ" onda ve varsayılan
    // seçili o). Mağaza ürünleri hangi sırayla döndürürse döndürsün.
    PlusPlans.setProducts(<PlusPlan>[
      const PlusPlan(
          id: PlusPlans.monthlyId, priceLabel: 'A', perMonthLabel: 'A'),
      const PlusPlan(
          id: PlusPlans.yearlyId,
          priceLabel: 'B',
          perMonthLabel: 'C',
          savingPercent: 33),
    ]);
    expect(PlusPlans.isConfigured, isTrue);
    expect(PlusPlans.current.first.id, PlusPlans.yearlyId);
    expect(PlusPlans.defaultPlan?.savingPercent, 33);
    PlusPlans.resetForTest();
  });

  test('tanınmayan ürün kimliği listeye girmiyor', () {
    // Mağaza bir gün fazladan ürün döndürürse ekran onu ÇİZMEMELİ: iki plan
    // kartı tasarımın şartı ve tanımadığımız bir ürünün fiyatını göstermek
    // kullanıcıya anlamadığımız bir şey satmak olurdu.
    PlusPlans.setProducts(<PlusPlan>[
      const PlusPlan(id: 'baska_urun', priceLabel: 'X', perMonthLabel: 'X'),
    ]);
    expect(PlusPlans.current, isEmpty);
    expect(PlusPlans.isConfigured, isFalse);
    PlusPlans.resetForTest();
  });

  testWidgets('ff_iap KAPALIYKEN satın alma yüzeyi kapanıyor',
      (WidgetTester tester) async {
    // Task 17. Bayrak bir KILL SWITCH ve üretim kodunda TEK BİR OKUYUCUSU
    // yoktu: `app_config`'e `ff_iap = 'false'` yazmak hiçbir şeyi
    // değiştirmiyordu. Diğer üç bayrağın hepsinin gerçek okuyucusu var.
    //
    // ÜRÜNLER TANIMLI OLMAK ZORUNDA: `resetForTest()` ile boş bırakılsaydı
    // yüzey zaten `isConfigured` yüzünden kapalı olurdu ve test bayrağı hiç
    // sınamazdı. (İlk yazımı tam bu yüzden mutasyonu ISIRMADI.)
    PlusPlans.setProducts(const <PlusPlan>[
      PlusPlan(id: 'kimo_plus_monthly', priceLabel: '₺99,99',
          perMonthLabel: '₺99,99'),
    ]);
    addTearDown(PlusPlans.resetForTest);
    await pumpPlus(tester, iapEnabled: false);
    final KimoButton cta = tester.widget<KimoButton>(
        find.widgetWithText(KimoButton, l.plusCta(PlusPlans.trialDays)));
    expect(cta.onPressed, isNull);
    expect(find.text(l.plusNotAvailableYet), findsOneWidget);
  });

  // ===================================================== ABONE OLANIN EKRANI
  //
  // T17-5: sunucu abonelik durumunu 0092'den beri yayınlıyordu, `DailyState`
  // onu modele kadar okuyordu ve HİÇBİR EKRAN sormuyordu. Parasını ödemiş
  // kullanıcı Kimo Plus'ı açınca satış sayfasını ve "7 gün ücretsiz dene"
  // düğmesini görüyordu — hem yanlış hem de mağaza kuralına aykırı (mevcut
  // aboneye ücretsiz deneme teklif edilemiyor).
  /// Durum kartı listenin altında; `ListView` görünür olmayanı KURMUYOR.
  Future<void> scrollToBottom(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pump(const Duration(seconds: 1));
  }

  group('etkin abonelik', () {
    testWidgets('deneme CTA\'sı ve plan seçici YOK, durum kartı VAR',
        (WidgetTester tester) async {
      PlusPlans.resetForTest();
      await pumpPlus(
        tester,
        subStatus: 'active',
        subExpiresAt: DateTime(2027, 10, 15),
        subRenews: true,
      );
      await scrollToBottom(tester);
      expect(find.text(l.plusCta(PlusPlans.trialDays)), findsNothing,
          reason: 'mevcut aboneye ücretsiz deneme teklif edilemez');
      expect(find.text(l.plusRestore), findsNothing,
          reason: 'etkin abonelikte geri yüklenecek bir şey yok');
      expect(find.text(l.plusActiveTitle), findsOneWidget);
      expect(find.text(l.plusActiveRenews('15 Ekim 2027')), findsOneWidget);
    });

    testWidgets('iptal edilmiş ama süresi dolmamış: BİTİŞ cümlesi',
        (WidgetTester tester) async {
      PlusPlans.resetForTest();
      await pumpPlus(
        tester,
        subStatus: 'active',
        subExpiresAt: DateTime(2026, 11, 3),
        subRenews: false,
      );
      await scrollToBottom(tester);
      // Hak ödenen dönemin sonuna kadar duruyor; `apply_subscription` iptali
      // premium'dan düşürmüyor. Cümle bunu söylemeli.
      expect(find.text(l.plusActiveEnds('3 Kasım 2026')), findsOneWidget);
      expect(find.text(l.plusActiveRenews('3 Kasım 2026')), findsNothing);
    });

    testWidgets('deneme sürerken başlık DENEME diyor',
        (WidgetTester tester) async {
      PlusPlans.resetForTest();
      await pumpPlus(tester,
          subStatus: 'trial',
          subExpiresAt: DateTime(2026, 9, 25),
          subRenews: true);
      await scrollToBottom(tester);
      expect(find.text(l.plusActiveTrialTitle), findsOneWidget);
      expect(find.text(l.plusActiveTitle), findsNothing);
    });

    testWidgets('ödemesiz dönemde ne yapılacağı yazıyor',
        (WidgetTester tester) async {
      PlusPlans.resetForTest();
      await pumpPlus(tester, subStatus: 'grace', subRenews: true);
      await scrollToBottom(tester);
      expect(find.text(l.plusActiveGraceTitle), findsOneWidget);
      expect(find.text(l.plusActiveGraceBody), findsOneWidget);
    });

    testWidgets('tarih gelmediyse UYDURULMUYOR', (WidgetTester tester) async {
      PlusPlans.resetForTest();
      await pumpPlus(tester, subStatus: 'active', subRenews: true);
      await scrollToBottom(tester);
      expect(find.text(l.plusActiveNoDate), findsOneWidget);
    });

    testWidgets('süresi dolmuş abonelik satış sayfasını GERİ getiriyor',
        (WidgetTester tester) async {
      PlusPlans.resetForTest();
      await pumpPlus(tester, subStatus: 'expired');
      expect(find.text(l.plusCta(PlusPlans.trialDays)), findsOneWidget);
      expect(find.text(l.plusActiveTitle), findsNothing);
    });
  });
}
