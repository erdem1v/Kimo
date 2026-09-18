import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/features/practice/session_end_screen.dart';
import 'package:kimo/features/practice/session_result.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/theme/app_theme.dart';

/// Oturum sonu ekranı (Task 18). `gems_hidden_test` yalnızca elmasın
/// gizlendiğini sabitliyor; ekranın ÇIKIŞLARI hiç sınanmamıştı:
/// "Bir tur daha" yalnızca çağıran izin verdiyse ve çözülecek soru kaldıysa
/// çiziliyor ve `true` döndürüyor; kapatma hedefi her durumda var ve `false`
/// döndürüyor (Task 15 · D4 — kapatması olmayan ekran).
void main() {
  late L10n l;
  setUpAll(() async => l = await L10n.delegate.load(const Locale('tr')));

  SessionResult result({int remaining = 3}) => SessionResult(
        solved: 4,
        correct: 3,
        firstTryCorrect: 2,
        longestCombo: 2,
        xpGained: 40,
        gemsAwarded: 0,
        streak: 1,
        streakGrew: true,
        totalXp: 140,
        remaining: remaining,
        goalReached: false,
      );

  Future<bool?> open(WidgetTester tester, SessionEndScreen screen) async {
    bool? popped;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: Builder(
        builder: (BuildContext ctx) => Scaffold(
          body: TextButton(
            onPressed: () async {
              popped = await Navigator.of(ctx).push<bool>(
                  MaterialPageRoute<bool>(builder: (_) => screen));
            },
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pump(); // rota itildi, geçiş başladı
    await tester.pump(const Duration(milliseconds: 600)); // geçiş bitti
    return popped;
  }

  testWidgets('devam izni + kalan soru → "bir tur daha" TRUE döndürüyor',
      (WidgetTester tester) async {
    await open(tester,
        SessionEndScreen(result: result(remaining: 3), canContinue: true));
    final Finder more = find.text(l.sessionExtraRound(3));
    expect(more, findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.byType(SessionEndScreen), findsNothing);
  });

  testWidgets('devam izni yoksa "bir tur daha" ÇİZİLMİYOR',
      (WidgetTester tester) async {
    await open(tester, SessionEndScreen(result: result(remaining: 3)));
    expect(find.text(l.sessionExtraRound(3)), findsNothing);
    expect(find.text(l.sessionContinue), findsOneWidget);
  });

  testWidgets('kalan soru yoksa izin olsa da "bir tur daha" yok',
      (WidgetTester tester) async {
    await open(tester,
        SessionEndScreen(result: result(remaining: 0), canContinue: true));
    expect(find.text(l.sessionExtraRound(0)), findsNothing);
  });

  testWidgets('kapatma hedefi VAR ve false döndürüyor (D4)',
      (WidgetTester tester) async {
    await open(tester,
        SessionEndScreen(result: result(remaining: 3), canContinue: true));
    final Finder close = find.byTooltip(l.actionClose);
    expect(close, findsOneWidget);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byType(SessionEndScreen), findsNothing);
  });
}
