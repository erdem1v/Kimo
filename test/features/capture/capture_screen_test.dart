import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/daily_state_repository.dart';
import 'package:kimo/features/capture/capture_screen.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/models/ai_credit.dart';
import 'package:kimo/models/social.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:kimo/widgets/kit/kimo_icons.dart';

/// Çekim ekranı (Task 18 · kapanış turu bulgusu).
///
/// Çoklu çekim anahtarı `Row(children: [SegmentedTabs])` içindeydi;
/// `SegmentedTabs` kendi içinde `Expanded` taşıyor ve `Row` ona sınırsız
/// genişlik veriyor → RenderFlex hatası → ekranın ORTASI HİÇ ÇİZİLMİYORDU
/// (ne maskot ne metin ne anahtar). Bayrak üretimde kapalı olduğu için hiçbir
/// tur görmemişti. Bu test anahtar açıkken ekranın kurulduğunu ve içeriğin
/// çizildiğini sabitliyor; eski yerleşim istisna fırlattığı için kırmızı.
void main() {
  late L10n l;
  setUpAll(() async => l = await L10n.delegate.load(const Locale('tr')));
  tearDown(() => DailyStateRepository.readOverride = null);

  DailyState state({required bool multi, required AiTier tier}) => DailyState(
        aiState: AiState.ok,
        aiLeft: 7,
        aiTier: tier,
        gems: 0,
        xp: 0,
        streak: 0,
        weeklyXp: 0,
        league: League.bronz,
        aiWindowLimit: 10,
        aiWindowHours: 8,
        ffMultiCapture: multi,
      );

  Future<void> pump(WidgetTester tester, DailyState s) async {
    DailyStateRepository.readOverride = () async => s;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: const CaptureScreen(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('bayrak + premium: anahtar VE içerik birlikte çiziliyor',
      (WidgetTester tester) async {
    await pump(tester, state(multi: true, tier: AiTier.premium));
    expect(find.text(l.captureModeSingle), findsOneWidget);
    expect(find.text(l.captureModeBatch), findsOneWidget);
    expect(find.text(l.captureEmptyTitle), findsOneWidget,
        reason: 'anahtar açıkken ekranın ortası boş kalmamalı');
    expect(find.byWidgetPredicate(
            (Widget w) => w is KimoIcon && w.icon == KimoIcons.lock),
        findsNothing, reason: 'premium kullanıcıda kilit yok');
  });

  testWidgets('bayrak + ücretsiz: anahtar kilitli ama içerik yerinde',
      (WidgetTester tester) async {
    await pump(tester, state(multi: true, tier: AiTier.free));
    expect(find.text(l.captureModeBatch), findsOneWidget);
    expect(find.byWidgetPredicate(
            (Widget w) => w is KimoIcon && w.icon == KimoIcons.lock),
        findsOneWidget);
    expect(find.text(l.captureEmptyTitle), findsOneWidget);
  });

  testWidgets('bayrak kapalı: anahtar hiç çizilmiyor', (WidgetTester tester) async {
    await pump(tester, state(multi: false, tier: AiTier.premium));
    expect(find.text(l.captureModeBatch), findsNothing);
    expect(find.text(l.captureEmptyTitle), findsOneWidget);
  });
}
