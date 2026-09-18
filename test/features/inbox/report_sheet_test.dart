import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/friend_repository.dart';
import 'package:kimo/features/inbox/inbox_screen.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/models/models.dart';
import 'package:kimo/models/received_question.dart';
import 'package:kimo/models/report_reason.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:kimo/widgets/kit/kimo_button.dart';

/// Gelen kutusu "Bildir" sayfası (Task 18). Üç söz: sebep seçilmeden
/// "Gönder" KAPALI (boş şikâyet yok); "Vazgeç" her durumda var (Task 15 ·
/// D3 — kapatması olmayan sayfa); sunucu reddederse sayfa AÇIK kalıyor ve
/// sebep yazıyor. Şikâyet tek çağrıda gidiyor (sebep + not + engelle).
void main() {
  late L10n l;
  setUpAll(() async => l = await L10n.delegate.load(const Locale('tr')));
  tearDown(() => FriendRepository.reportOverride = null);

  final ReceivedQuestion q = const ReceivedQuestion(
    sendId: 's1',
    senderId: 'u2',
    senderNickname: 'Efe',
    subject: 'Matematik',
    concept: 'Türev',
    photoPath: 'u2/x.jpg',
    options: <QuestionOption>[],
  );

  Future<Future<bool?>> open(WidgetTester tester) async {
    late Future<bool?> result;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: Builder(
        builder: (BuildContext ctx) => Scaffold(
          body: TextButton(
            onPressed: () => result = showReportSheet(ctx, q),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    return result;
  }

  Finder send() => find.widgetWithText(KimoButton, l.inboxReportSend);

  testWidgets('sebep seçilmeden Gönder KAPALI, Vazgeç VAR',
      (WidgetTester tester) async {
    await open(tester);
    expect(tester.widget<KimoButton>(send()).onPressed, isNull);
    expect(find.widgetWithText(KimoButton, l.actionCancel), findsOneWidget);
    await tester.tap(find.text(ReportReason.inbox.first.label));
    await tester.pump();
    expect(tester.widget<KimoButton>(send()).onPressed, isNotNull);
  });

  testWidgets('gönderim TEK çağrı: sebep + engelle birlikte gidiyor',
      (WidgetTester tester) async {
    final List<String> calls = <String>[];
    FriendRepository.reportOverride = ({
      required String sendId,
      required ReportReason reason,
      String? note,
      bool block = false,
    }) async =>
        calls.add('$sendId ${reason.name} block=$block');
    final Future<bool?> result = await open(tester);
    await tester.tap(find.text(ReportReason.inbox.first.label));
    await tester.pump();
    await tester.ensureVisible(find.text(l.inboxReportBlockAlso));
    await tester.tap(find.text(l.inboxReportBlockAlso));
    await tester.pump();
    await tester.ensureVisible(send());
    await tester.tap(send());
    await tester.pumpAndSettle();
    expect(calls, <String>['s1 ${ReportReason.inbox.first.name} block=true']);
    expect(await result, isTrue);
    expect(find.text(l.inboxReportSent), findsOneWidget);
  });

  testWidgets('sunucu reddederse sayfa AÇIK, sebep yazıyor, tekrar denenebilir',
      (WidgetTester tester) async {
    FriendRepository.reportOverride = ({
      required String sendId,
      required ReportReason reason,
      String? note,
      bool block = false,
    }) async =>
        throw Exception('503');
    await open(tester);
    await tester.tap(find.text(ReportReason.inbox.first.label));
    await tester.pump();
    await tester.ensureVisible(send());
    await tester.tap(send());
    await tester.pump();
    await tester.pump();
    expect(find.text(l.inboxReportFailed), findsOneWidget);
    expect(send(), findsOneWidget, reason: 'sayfa kapanmamalı');
    expect(tester.widget<KimoButton>(send()).onPressed, isNotNull,
        reason: 'düğme meşgulde takılı kalmamalı');
  });
}
