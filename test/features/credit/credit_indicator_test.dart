import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/daily_state_repository.dart';
import 'package:kimo/features/credit/credit_indicator.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/models/ai_credit.dart';
import 'package:kimo/models/social.dart';
import 'package:kimo/theme/app_theme.dart';

/// Hak göstergesinin BEŞ durumu.
///
/// Metin üretimi saf bir fonksiyon (`creditIndicatorText`), o yüzden çoğu
/// iddia widget pompalamadan kurulabiliyor. Pompalanan tek şey kırpma ve
/// "hiç çizilmiyor" davranışı.
DailyState state({
  AiState? aiState = AiState.ok,
  int? aiLeft = 7,
  String? nextAtHm = '14:30',
  DateTime? monthResetsOn,
  AiTier tier = AiTier.free,
}) {
  return DailyState(
    aiState: aiState,
    aiLeft: aiLeft,
    aiTier: tier,
    gems: 0,
    xp: 0,
    streak: 0,
    weeklyXp: 0,
    league: League.bronz,
    aiNextAtHm: nextAtHm,
    aiMonthResetsOn: monthResetsOn,
  );
}

void main() {
  late L10n l;

  setUpAll(() async {
    l = await L10n.delegate.load(const Locale('tr'));
  });

  group('beş durum', () {
    test('1. ok → yalnızca sayı, saat YOK', () {
      final String? t = creditIndicatorText(l, state());
      expect(t, '7 hakkın kaldı');
      expect(t, isNot(contains('14:30')));
    });

    test('2. low → sayı VE sonraki hakkın saati', () {
      expect(
        creditIndicatorText(l, state(aiState: AiState.low, aiLeft: 2)),
        "2 hakkın kaldı · sonraki 14:30'da",
      );
    });

    test('3. window_full → saat var, sayı yok', () {
      final String? t = creditIndicatorText(
          l, state(aiState: AiState.windowFull, aiLeft: 0));
      expect(t, "Hakların doldu · sonraki 14:30'da");
      expect(t, isNot(contains('0 hak')));
    });

    test('4. month_full → ay tarihi; PENCERE SAATİ ASLA GÖSTERİLMİYOR', () {
      // `nextAtHm` DOLU verilmesine rağmen metinde geçmemeli. Ürün kuralı:
      // aylık sınır dolduğunda o saat artık bir şey vaat etmiyor. Sunucu da
      // alanı null gönderiyor; bu iddia istemcinin ona BAĞLI OLMADIĞINI
      // kanıtlıyor.
      final String? t = creditIndicatorText(
        l,
        state(
          aiState: AiState.monthFull,
          aiLeft: 0,
          nextAtHm: '14:30',
          monthResetsOn: DateTime(2026, 10, 1),
        ),
      );
      expect(t, "Bu ay hakkın doldu · 1 Ekim'de yenilenir");
      expect(t, isNot(contains('14:30')));
      expect(t, isNot(contains('sonraki')));
    });

    test('5. lifetime_full (anonim) → saat yok', () {
      final String? t = creditIndicatorText(
        l,
        state(aiState: AiState.lifetimeFull, aiLeft: 0, tier: AiTier.anonymous),
      );
      expect(t, 'Deneme hakkın doldu');
      expect(t, isNot(contains('14:30')));
    });
  });

  group('okunamadı → HİÇBİR ŞEY (sıfır DEĞİL)', () {
    test('durum okunamadı', () {
      expect(creditIndicatorText(l, null), isNull);
    });

    test('ai_state tanınmadı', () {
      expect(creditIndicatorText(l, state(aiState: null)), isNull);
    });

    test('sayı gelmedi', () {
      expect(creditIndicatorText(l, state(aiLeft: null)), isNull);
    });

    test('window_full ama saat eksik → delikli cümle basmıyor', () {
      expect(
        creditIndicatorText(
            l, state(aiState: AiState.windowFull, aiLeft: 0, nextAtHm: null)),
        isNull,
      );
    });

    test('month_full ama tarih eksik', () {
      expect(
        creditIndicatorText(
            l, state(aiState: AiState.monthFull, aiLeft: 0,
                     monthResetsOn: null)),
        isNull,
      );
    });

    test('askıya alınmış kullanıcıda hak konuşmuyor', () {
      expect(
        creditIndicatorText(l, state(aiState: AiState.suspended, aiLeft: 0)),
        isNull,
      );
    });
  });

  group('widget', () {
    Future<void> pumpIn(WidgetTester tester, DailyState? s) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: AppTheme.light(),
        home: Scaffold(body: Row(children: <Widget>[
          Flexible(child: CreditIndicator(state: s)),
        ])),
      ));
      await tester.pump(const Duration(milliseconds: 32));
    }

    testWidgets('okunamadığında HİÇBİR metin ve özellikle "0" çizilmiyor',
        (WidgetTester tester) async {
      await pumpIn(tester, null);
      // Sıfır göstermek gerçekten sıfır olmasıyla ayırt edilemezdi — eski
      // `?? 5` / `?? 0` yedeklerinin ürettiği hata tam buydu.
      expect(find.text('0'), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('hak varken sayı çiziliyor', (WidgetTester tester) async {
      await pumpIn(tester, state());
      expect(find.text('7 hakkın kaldı'), findsOneWidget);
    });

    testWidgets('uzun month_full metni satırı TAŞIRMIYOR',
        (WidgetTester tester) async {
      // 360dp: seri hapı ve seviye metniyle birlikte en dar gerçek durum.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpIn(
        tester,
        state(
          aiState: AiState.monthFull,
          aiLeft: 0,
          monthResetsOn: DateTime(2026, 10, 1),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
