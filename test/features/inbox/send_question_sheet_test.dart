import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/social_repository.dart';
import 'package:kimo/features/inbox/send_question_sheet.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:kimo/widgets/kit/kimo_button.dart';

/// Arkadaşa gönderme sayfası (Task 18). Arkadaş listesi yüklenemediğinde
/// sayfa bir çıkmaz sokağa dönüşmemeli: hata metni + "Tekrar dene" + kapatma
/// hedefi ÜÇÜ birden var (Task 15 · D3). Hata dalındaki kapatma silinince
/// bu dosya kırmızıya dönüyor.
void main() {
  late L10n l;
  setUpAll(() async => l = await L10n.delegate.load(const Locale('tr')));
  tearDown(() => SocialRepository.relationsOverride = null);

  testWidgets('liste yüklenemedi: hata + tekrar dene + KAPAT',
      (WidgetTester tester) async {
    int attempts = 0;
    SocialRepository.relationsOverride = () async {
      attempts++;
      throw Exception('ağ yok');
    };
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: Builder(
        builder: (BuildContext ctx) => Scaffold(
          body: TextButton(
            onPressed: () =>
                showSendQuestionSheet(ctx, mistakeId: 'm1', title: 'Türev'),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    expect(find.text(l.sendLoadFailed), findsOneWidget);
    expect(find.byTooltip(l.actionClose), findsOneWidget,
        reason: 'hata dalında da kapatma hedefi olmalı');
    final Finder retry = find.widgetWithText(KimoButton, l.actionRetry);
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(attempts, 2, reason: 'tekrar dene gerçekten yeniden yüklemeli');

    await tester.tap(find.byTooltip(l.actionClose));
    await tester.pumpAndSettle();
    expect(find.text(l.sendLoadFailed), findsNothing, reason: 'sayfa kapandı');
  });
}
