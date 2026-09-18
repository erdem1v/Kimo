import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/features/practice/answer_reveal.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/theme/app_theme.dart';

/// Cevap paneli (Task 18). Panel SUNUCUNUN söylediğini yazıyor, kendi
/// hesaplamıyor: plan yazılamadıysa "N gün sonra" sözü VERİLMİYOR ve durum
/// açıkça söyleniyor; XP/kombo rozetleri yalnızca sunucu bir sayı döndürdüyse
/// çiziliyor (çevrimdışı kuyrukta ikisi de null); son soruda düğme "bitir".
/// Sessiz-plan-hatası dalı kaldırılınca bu dosya kırmızıya dönüyor.
void main() {
  late L10n l;
  setUpAll(() async => l = await L10n.delegate.load(const Locale('tr')));

  Future<void> pump(WidgetTester tester, AnswerOutcome o,
      {bool isLast = false}) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: Scaffold(
        body: AnswerReveal(outcome: o, isLast: isLast, onContinue: () {}),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('plan yazıldı: "N gün sonra" ve rozetler',
      (WidgetTester tester) async {
    await pump(
        tester,
        const AnswerOutcome(
            correct: true,
            nextIntervalDays: 3,
            mastered: false,
            xpAwarded: 10,
            multiplier: 2));
    expect(find.text(l.practiceCorrectTitle), findsOneWidget);
    expect(find.text(l.practiceNextInDays(3)), findsOneWidget);
    expect(find.text(l.practiceXpGain(10)), findsOneWidget);
    expect(find.text(l.practiceCombo(2)), findsOneWidget);
    expect(find.text(l.practiceScheduleFailed), findsNothing);
    expect(find.text(l.practiceNext), findsOneWidget);
  });

  testWidgets('plan YAZILAMADI: uyarı var, gün sözü YOK',
      (WidgetTester tester) async {
    await pump(
        tester,
        const AnswerOutcome(
            correct: true,
            nextIntervalDays: 3,
            mastered: false,
            scheduleFailed: true));
    expect(find.text(l.practiceScheduleFailed), findsOneWidget);
    expect(find.text(l.practiceNextInDays(3)), findsNothing,
        reason: 'yazılamayan plan için tarih vaat edilemez');
  });

  testWidgets('sunucu sayı döndürmediyse (kuyruk) rozet YOK',
      (WidgetTester tester) async {
    await pump(
        tester,
        const AnswerOutcome(
            correct: true, nextIntervalDays: 1, mastered: false));
    expect(find.textContaining('XP'), findsNothing);
    expect(find.text(l.practiceCombo(1)), findsNothing);
  });

  testWidgets('çarpan 1 ise kombo rozeti yok, XP var',
      (WidgetTester tester) async {
    await pump(
        tester,
        const AnswerOutcome(
            correct: true,
            nextIntervalDays: 1,
            mastered: false,
            xpAwarded: 5,
            multiplier: 1));
    expect(find.text(l.practiceXpGain(5)), findsOneWidget);
    expect(find.text(l.practiceCombo(1)), findsNothing);
  });

  testWidgets('hâkim olunan soru + son soru: hâkim metni ve "bitir"',
      (WidgetTester tester) async {
    await pump(
        tester,
        const AnswerOutcome(correct: true, nextIntervalDays: 0, mastered: true),
        isLast: true);
    expect(find.text(l.practiceMasteredBody), findsOneWidget);
    expect(find.text(l.practiceFinish), findsOneWidget);
    expect(find.text(l.practiceNext), findsNothing);
  });
}
