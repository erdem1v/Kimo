import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/daily_state_repository.dart';
import 'package:kimo/features/credit/credit_indicator.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/models/ai_credit.dart';
import 'package:kimo/models/social.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:kimo/widgets/kit/kimo_icons.dart';
import 'package:kimo/widgets/kit/kimo_progress.dart';

/// Hak göstergesinin ALTI durumu — TEK KALP + RAKAM (Tur 7 · n1).
///
/// Görünüm kararı saf bir fonksiyonda (`creditPillSpec`), o yüzden çoğu iddia
/// widget pompalamadan kurulabiliyor. Pompalanan şeyler: ikonun dolu mu kontur
/// mu çizildiği, nabzın dönüp dönmediği, kırpma ve "hiç çizilmiyor" davranışı.
///
/// TASK 10 İLİŞKİSİ: kalp geri geldi ama Task 10'un ikinci yarısı yürürlükte —
/// hapta o eski kelime YOK. Aşağıdaki iddialar hapta yalnızca rakam/saat/tarih
/// olduğunu, tam cümlenin ise `semanticLabel`'da durduğunu sabitliyor.
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

  group('altı durum — hap içeriği ve ikon', () {
    test('1. ok → dolu kalp, YALNIZCA sayı, saat yok, nabız yok', () {
      final CreditPillSpec? s = creditPillSpec(l, state());
      expect(s, isNotNull);
      expect(s!.filled, isTrue);
      expect(s.text, '7');
      expect(s.timeText, isNull);
      expect(s.pulse, isFalse);
      expect(s.tone, CreditTone.coral);
      // Tam cümle KAYBOLMADI, yalnızca yer değiştirdi.
      expect(s.semanticLabel, '7 hakkın kaldı');
    });

    test('2. low → dolu kalp, sayı + saat, NABIZ AÇIK, bal rengi', () {
      final CreditPillSpec? s =
          creditPillSpec(l, state(aiState: AiState.low, aiLeft: 2));
      expect(s!.filled, isTrue);
      expect(s.text, '2');
      expect(s.timeText, '14:30');
      expect(s.pulse, isTrue);
      expect(s.tone, CreditTone.honey);
      expect(s.semanticLabel, "2 hakkın kaldı · sonraki 14:30'da");
    });

    test('3. window_full → KONTUR kalp, saat var, RAKAM YOK, nabız YOK', () {
      final CreditPillSpec? s = creditPillSpec(
          l, state(aiState: AiState.windowFull, aiLeft: 0));
      expect(s!.filled, isFalse);
      // Tam eşitlik zaten rakamın olmadığını kanıtlıyor: sıfır yazılmıyor.
      expect(s.text, 'Sonraki 14:30');
      expect(s.timeText, isNull, reason: 'saat metnin İÇİNDE, ayrı alanda değil');
      // Tasarımın açık kuralı: sıfıra düşünce nabız DURUR, yanıp sönme yok.
      expect(s.pulse, isFalse);
      expect(s.tone, CreditTone.neutral);
    });

    test('4. month_full → tarih; PENCERE SAATİ ASLA GÖSTERİLMİYOR', () {
      // `nextAtHm` DOLU verilmesine rağmen hiçbir yerde geçmemeli. Ürün
      // kuralı: aylık sınır dolduğunda o saat artık bir şey vaat etmiyor.
      // Sunucu da alanı null gönderiyor; bu iddia istemcinin ona BAĞLI
      // OLMADIĞINI kanıtlıyor.
      final CreditPillSpec? s = creditPillSpec(
        l,
        state(
          aiState: AiState.monthFull,
          aiLeft: 0,
          nextAtHm: '14:30',
          monthResetsOn: DateTime(2026, 10, 1),
        ),
      );
      expect(s!.filled, isFalse);
      expect(s.text, '1 Ekim');
      expect(s.text, isNot(contains('14:30')));
      expect(s.timeText, isNull);
      // Hapta EKSİZ, ekran okuyucuda EKLİ.
      expect(s.semanticLabel, "Bu ay hakkın doldu · 1 Ekim'de yenilenir");
    });

    test('5. lifetime_full (anonim) → kontur kalp + KİLİT, metin yok', () {
      final CreditPillSpec? s = creditPillSpec(
        l,
        state(aiState: AiState.lifetimeFull, aiLeft: 0, tier: AiTier.anonymous),
      );
      expect(s!.filled, isFalse);
      expect(s.locked, isTrue);
      expect(s.text, isEmpty);
      expect(s.semanticLabel, 'Deneme hakkın doldu');
    });

    test('6. suspended → HİÇBİR ŞEY', () {
      expect(
        creditPillSpec(l, state(aiState: AiState.suspended, aiLeft: 0)),
        isNull,
      );
    });
  });

  group('okunamadı → HİÇBİR ŞEY (sıfır DEĞİL)', () {
    test('durum okunamadı', () {
      expect(creditPillSpec(l, null), isNull);
    });

    test('ai_state tanınmadı', () {
      expect(creditPillSpec(l, state(aiState: null)), isNull);
    });

    test('sayı gelmedi', () {
      expect(creditPillSpec(l, state(aiLeft: null)), isNull);
    });

    test('window_full ama saat eksik → delikli hap basmıyor', () {
      expect(
        creditPillSpec(
            l, state(aiState: AiState.windowFull, aiLeft: 0, nextAtHm: null)),
        isNull,
      );
    });

    test('month_full ama tarih eksik', () {
      expect(
        creditPillSpec(
            l, state(aiState: AiState.monthFull, aiLeft: 0,
                     monthResetsOn: null)),
        isNull,
      );
    });
  });

  group('widget', () {
    Future<void> pumpIn(
      WidgetTester tester,
      DailyState? s, {
      double textScale = 1.0,
      bool reduceMotion = false,
    }) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: Scaffold(
            body: Row(children: <Widget>[
              Flexible(child: CreditIndicator(state: s)),
            ]),
          ),
        ),
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
      expect(find.byType(KimoIcon), findsNothing);
    });

    testWidgets('hak varken DOLU kalp ve rakam çiziliyor',
        (WidgetTester tester) async {
      await pumpIn(tester, state());
      expect(find.text('7'), findsOneWidget);
      final KimoIcon icon = tester.widget(find.byType(KimoIcon));
      expect(icon.icon, same(KimoIcons.heart));
      // Hapta cümle YOK.
      expect(find.text('7 hakkın kaldı'), findsNothing);
    });

    testWidgets('pencere dolunca KONTUR kalp çiziliyor',
        (WidgetTester tester) async {
      await pumpIn(tester, state(aiState: AiState.windowFull, aiLeft: 0));
      final KimoIcon icon = tester.widget(find.byType(KimoIcon));
      expect(icon.icon, same(KimoIcons.heartOutline));
    });

    testWidgets('tam cümle ekran okuyucuya gidiyor',
        (WidgetTester tester) async {
      await pumpIn(tester, state());
      // `HudPill` etiketi `Semantics` ile veriyor; hap kısaldı ama erişilebilir
      // metin kısalmadı.
      final HudPill pill = tester.widget(find.byType(HudPill));
      expect(pill.semanticLabel, '7 hakkın kaldı');
    });

    testWidgets('low durumunda nabız DÖNÜYOR, window_full''da DURUYOR',
        (WidgetTester tester) async {
      await pumpIn(tester, state(aiState: AiState.low, aiLeft: 2));
      final Finder beat = find.byKey(beatKey);
      expect(beat, findsOneWidget);
      final double before = tester.widget<ScaleTransition>(beat).scale.value;
      await tester.pump(const Duration(milliseconds: 400));
      final double after = tester.widget<ScaleTransition>(beat).scale.value;
      expect(after, isNot(before), reason: 'nabız ilerliyor');

      // Pencere dolunca nabız HİÇ kurulmuyor.
      await pumpIn(tester, state(aiState: AiState.windowFull, aiLeft: 0));
      expect(find.byKey(beatKey), findsNothing);
    });

    testWidgets('hareketi azalt: nabız ve pop KAPALI',
        (WidgetTester tester) async {
      await pumpIn(tester, state(aiState: AiState.low, aiLeft: 2),
          reduceMotion: true);
      expect(find.byKey(beatKey), findsNothing);
      expect(find.byKey(popKey), findsNothing);
      // İçerik yine çiziliyor: hareket kapandı, bilgi kapanmadı.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('14:30'), findsOneWidget);
    });

    testWidgets('360dp ve BÜYÜK YAZI ölçeğinde taşma yok',
        (WidgetTester tester) async {
      // 360dp: seri hapı ve seviye metniyle birlikte en dar gerçek durum.
      // Metin ölçeği 1.3: eski uzun cümle burada taşıyordu, kısa hap taşımıyor.
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
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
