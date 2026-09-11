import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/daily_state_repository.dart';
import 'package:kimo/features/credit/credit_wall_screen.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/models/ai_credit.dart';
import 'package:kimo/models/social.dart';
import 'package:kimo/services/ads/ad_service.dart';
import 'package:kimo/state/credit_wall_log.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:kimo/widgets/kit/kimo_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sahte reklam servisi — gerçek eklentiye hiç dokunmadan üç yollu sözleşmeyi
/// sınamanın tek yolu.
class FakeAdService implements AdService {
  FakeAdService({this.supported = true, this.isReady = true});

  @override
  final bool supported;
  @override
  final bool isReady;

  @override
  Future<void> init() async {}
  @override
  Future<void> preload() async {}
  @override
  Future<AdOutcome> showRewarded({required String nonce}) async =>
      AdOutcome.earned;
  @override
  void dispose() {}
}

DailyState wallState({
  AiState aiState = AiState.windowFull,
  AiTier tier = AiTier.free,
  int adRewardsLeft = 3,
  bool adOffer = true,
  int monthLeft = 250,
}) {
  return DailyState(
    aiState: aiState,
    aiLeft: 0,
    aiTier: tier,
    gems: 0,
    xp: 0,
    streak: 0,
    weeklyXp: 0,
    league: League.bronz,
    aiWindowLeft: 0,
    aiWindowLimit: 10,
    aiMonthLeft: monthLeft,
    aiMonthLimit: 300,
    aiWindowHours: 8,
    aiNextAtHm: '14:30',
    aiMonthResetsOn: DateTime(2026, 10, 1),
    adRewardsLeft: adRewardsLeft,
    adRewardsPerDay: 3,
    adOffer: adOffer,
    plusWindowLimit: 50,
    plusMonthLimit: 1000,
    weekStart: DateTime(2026, 9, 7),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late L10n l;

  setUpAll(() async {
    l = await L10n.delegate.load(const Locale('tr'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    AdService.useForTest(FakeAdService());
  });

  tearDown(AdService.resetForTest);

  /// `pumpAndSettle` KULLANILMIYOR: Kimo'nun boşta animasyonu hiç bitmiyor.
  Future<void> pumpWall(WidgetTester tester, DailyState s,
      {int arrivals = 1}) async {
    for (int i = 1; i < arrivals; i++) {
      await creditWallLog.bump(s.weekStart);
    }
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: CreditWallScreen(state: s),
    ));
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 32));
  }

  KimoButton saveButton(WidgetTester tester) {
    return tester.widget<KimoButton>(find.widgetWithText(
        KimoButton, l.creditWallSaveAction));
  }

  group('w1 — ilk çarpma: üç yol birlikte', () {
    testWidgets('reklam, Plus ve kaydetme yolunun ÜÇÜ DE görünüyor',
        (WidgetTester tester) async {
      await pumpWall(tester, wallState());
      expect(find.text(l.creditWallAdTitle), findsOneWidget);
      expect(find.text(l.creditWallPlusTitle), findsOneWidget);
      expect(find.text(l.creditWallSaveAction), findsOneWidget);
    });

    testWidgets('başlık pencere dolu; ay metni GEÇMİYOR',
        (WidgetTester tester) async {
      await pumpWall(tester, wallState());
      expect(find.text(l.creditWallTitleWindow), findsOneWidget);
      expect(find.text(l.creditWallTitleMonth), findsNothing);
    });

    testWidgets('ilk çarpmada Plus sıradan bir satır (kart DEĞİL)',
        (WidgetTester tester) async {
      await pumpWall(tester, wallState());
      // Renkli kartın işareti: kıyas tablosu ve deneme CTA'sı.
      expect(find.text(l.plusCta(7)), findsNothing);
    });
  });

  group('w2 — tekrar çarpma', () {
    testWidgets('Plus kartı ÖNE ÇIKIYOR (kıyas + CTA)',
        (WidgetTester tester) async {
      await pumpWall(tester, wallState(), arrivals: 3);
      expect(find.text(l.plusCta(7)), findsOneWidget);
    });

    testWidgets('aylık cap dolunca başlık AY, ve pencere saati geçmiyor',
        (WidgetTester tester) async {
      await pumpWall(
          tester, wallState(aiState: AiState.monthFull, monthLeft: 0,
              adOffer: false));
      expect(find.text(l.creditWallTitleMonth), findsOneWidget);
      expect(find.textContaining('14:30'), findsNothing);
      expect(find.textContaining('sonraki'), findsNothing);
    });

    testWidgets('w2 başlığı YALAN DEĞİL: pencereye üçüncü kez çarpanda hâlâ '
        'pencere başlığı', (WidgetTester tester) async {
      // Tasarım w2'ye tek başlık veriyor ("Bu ay analiz hakkın doldu") ama
      // üç tetikleyici sayıyor. Ayını bitirmemiş bir kullanıcıya o başlığı
      // göstermek yalan olurdu; başlık `ai_state`ten geliyor.
      await pumpWall(tester, wallState(), arrivals: 3);
      expect(find.text(l.creditWallTitleWindow), findsOneWidget);
      expect(find.text(l.creditWallTitleMonth), findsNothing);
    });
  });

  group('reklam yolu SESSİZ başarısız oluyor', () {
    testWidgets('doluluk yok → satır HİÇ çizilmiyor, hata YOK',
        (WidgetTester tester) async {
      AdService.useForTest(FakeAdService(isReady: false));
      await pumpWall(tester, wallState());
      expect(find.text(l.creditWallAdTitle), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('desteklenmeyen platform → satır yok, hata yok',
        (WidgetTester tester) async {
      AdService.useForTest(FakeAdService(supported: false));
      await pumpWall(tester, wallState());
      expect(find.text(l.creditWallAdTitle), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('günlük tavan dolu → TIKLANAMAZ bilgi satırı (kaybolmuyor)',
        (WidgetTester tester) async {
      await pumpWall(tester,
          wallState(adRewardsLeft: 0, adOffer: false));
      expect(find.text(l.creditWallAdCapTitle), findsOneWidget);
      expect(find.text(l.creditWallAdCapSubtitle(3)), findsOneWidget);
      // "İzle" düğmesi yok: dokunmanın karşılığı yok.
      expect(find.text(l.creditWallAdAction), findsNothing);
    });

    testWidgets('sunucu teklif etmiyorsa satır çizilmiyor',
        (WidgetTester tester) async {
      await pumpWall(tester, wallState(adOffer: false));
      expect(find.text(l.creditWallAdTitle), findsNothing);
    });
  });

  group('anonim dalı', () {
    testWidgets('reklam ve Plus YOK; kaydetme yolu duruyor',
        (WidgetTester tester) async {
      await pumpWall(
        tester,
        wallState(aiState: AiState.lifetimeFull, tier: AiTier.anonymous,
            adRewardsLeft: 0, adOffer: false),
      );
      expect(find.text(l.creditWallAdTitle), findsNothing);
      expect(find.text(l.creditWallPlusTitle), findsNothing);
      expect(find.text(l.creditWallSaveAction), findsOneWidget);
    });
  });

  // ======================================================================
  // ÜRÜNÜN DEĞİŞMEZ KURALI. Bu grup düşerse paket YAYINLANMAZ.
  // ======================================================================
  group('KAYDETME YOLU HİÇBİR DALDA KAPANMIYOR', () {
    final Map<String, DailyState> branches = <String, DailyState>{
      'w1 pencere dolu': wallState(),
      'aylık cap dolu': wallState(aiState: AiState.monthFull, monthLeft: 0,
          adOffer: false),
      'reklam tavanı dolu': wallState(adRewardsLeft: 0, adOffer: false),
      'reklam sunulmuyor': wallState(adOffer: false),
      'anonim ömür dolu': wallState(
          aiState: AiState.lifetimeFull, tier: AiTier.anonymous,
          adRewardsLeft: 0, adOffer: false),
    };

    branches.forEach((String name, DailyState s) {
      testWidgets('$name → düğme VAR, ETKİN ve TAM GENİŞLİK',
          (WidgetTester tester) async {
        await pumpWall(tester, s);
        expect(find.text(l.creditWallSaveAction), findsOneWidget);
        final KimoButton b = saveButton(tester);
        expect(b.onPressed, isNotNull, reason: '$name: düğme devre dışı');
        expect(b.expand, isTrue, reason: '$name: düğme küçültülmüş');
      });
    });

    testWidgets('tekrar çarpmada da (Plus öne çıkmışken) etkin ve tam genişlik',
        (WidgetTester tester) async {
      await pumpWall(tester, wallState(), arrivals: 3);
      final KimoButton b = saveButton(tester);
      expect(b.onPressed, isNotNull);
      expect(b.expand, isTrue);
      // Tasarım: "Elle giriş aynı boyutta ikinci buton olarak duruyor —
      // küçültülmedi." Dolgusu ikincil ama BOYUTU aynı.
      expect(b.kind, KimoButtonKind.secondary);
    });

    testWidgets('kaydetme bir KAPATMA değil: manualEntry döndürüyor',
        (WidgetTester tester) async {
      CreditWallOutcome? result;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: AppTheme.light(),
        home: Builder(builder: (BuildContext context) {
          return ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<CreditWallOutcome>(
                MaterialPageRoute<CreditWallOutcome>(
                  builder: (_) => CreditWallScreen(state: wallState()),
                ),
              );
            },
            child: const Text('ac'),
          );
        }),
      ));
      await tester.tap(find.text('ac'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(l.creditWallSaveAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(result, CreditWallOutcome.manualEntry);
      expect(result, isNot(CreditWallOutcome.dismissed));
    });
  });
}
