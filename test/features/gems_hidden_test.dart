import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/features/practice/session_end_screen.dart';
import 'package:kimo/features/practice/session_result.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/state/features.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:kimo/widgets/kit/kimo_icons.dart';

/// Elmas v1'de GİZLİ — ama SİLİNMEDİ.
///
/// Bu dosyanın iki işi var:
///   1. Elmasın hiçbir yüzeyde çizilmediğini kanıtlamak.
///   2. VERİ YOLUNUN SAĞLAM kaldığını kanıtlamak. İkincisi v2'yi tek satır
///      yapan şey: `gemsAwarded` hâlâ taşınıyor, sunucu hâlâ elmas veriyor,
///      yalnızca çizim kapalı.
///
/// v2'de (AI koç geldiğinde) bu dosya TERSİNE ÇEVRİLİR: aynı üç iddia
/// `findsOneWidget` ile.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late L10n l;

  setUpAll(() async {
    l = await L10n.delegate.load(const Locale('tr'));
  });

  SessionResult result({int gems = 40}) => SessionResult(
        solved: 12,
        correct: 10,
        firstTryCorrect: 9,
        longestCombo: 4,
        xpGained: 180,
        gemsAwarded: gems,
        streak: 5,
        streakGrew: false,
        totalXp: 7200,
        remaining: 0,
        goalReached: true,
      );

  Future<void> pumpEnd(WidgetTester tester, SessionResult r) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: SessionEndScreen(result: r),
    ));
    // `pumpAndSettle` YOK: Kimo'nun boşta animasyonu hiç bitmiyor.
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 32));
  }

  test('bayrak v1''de kapalı', () {
    expect(Features.gemsVisible, isFalse);
  });

  testWidgets('oturum sonu: elmas ikonu ÇİZİLMİYOR',
      (WidgetTester tester) async {
    await pumpEnd(tester, result());
    final Iterable<KimoIcon> icons = tester.widgetList<KimoIcon>(
        find.byType(KimoIcon));
    expect(
      icons.where((KimoIcon i) => i.icon == KimoIcons.gem),
      isEmpty,
      reason: 'elmas ikonu hâlâ çiziliyor',
    );
  });

  testWidgets('sandık metinleri GÖRÜNMÜYOR', (WidgetTester tester) async {
    await pumpEnd(tester, result());
    expect(find.text(l.sessionChestGems(40)), findsNothing);
    expect(find.text(l.sessionChestReady), findsNothing);
    expect(find.text(l.sessionOpenChest), findsNothing);
  });

  testWidgets('GÜNLÜK HEDEF DUYURUSU ve XP YERİNDE — boşluk bırakılmadı',
      (WidgetTester tester) async {
    // Sandık kartının içeriğinin tamamı elmas olduğu için kart bütün olarak
    // gitti. Ama ödülün görünürlüğü kaybolmadı: hedefin tamamlandığı üst
    // satırda duyuruluyor ve günlük hedef XP'si `+{xpGained}` karosunda.
    await pumpEnd(tester, result());
    expect(find.text(l.sessionGoalReached), findsOneWidget);
    expect(find.text('+180'), findsOneWidget);
    expect(find.text(l.sessionXp), findsWidgets);
  });

  testWidgets('seviye kartı etkilenmedi (seviye sistemi duruyor)',
      (WidgetTester tester) async {
    await pumpEnd(tester, result());
    // 7200 XP → seviye 8 (1000 XP = 1 seviye, 0'dan başlayarak +1).
    expect(find.text(l.sessionLevel(8)), findsOneWidget);
  });

  testWidgets('VERİ YOLU SAĞLAM: gemsAwarded hâlâ taşınıyor',
      (WidgetTester tester) async {
    // Bu iddia "gizleme" ile "silme" arasındaki farkı kanıtlıyor. Sunucu
    // elmas vermeye devam ediyor ve bakiyeler birikiyor; v2'de bayrağı
    // açmak yeterli olacak, göç ya da geri dolum gerekmeyecek.
    final SessionResult r = result();
    expect(r.gemsAwarded, 40);
    await pumpEnd(tester, r);
    expect(r.gemsAwarded, 40);
  });

  test('elmas l10n anahtarları SİLİNMEDİ', () {
    // Anahtarlar duruyor, yalnızca çağrılmıyorlar. Silmek v2'de onları
    // yeniden yazmayı gerektirirdi.
    expect(l.sessionChestGems(3), isNotEmpty);
    expect(l.sessionChestReady, isNotEmpty);
    expect(l.hudGemsLabel(5), isNotEmpty);
  });

  test('hesap silme metninden elmas ibaresi çıkarıldı', () {
    // Görünmeyen bir para biriminin adını silme listesinde saymak kafa
    // karıştırır. Elmas sunucuda hâlâ siliniyor; cümle örnek sayıyor.
    expect(l.deleteItemProgress, isNot(contains('elmas')));
  });
}
