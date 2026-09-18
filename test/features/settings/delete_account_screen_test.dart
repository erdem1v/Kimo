import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/account_repository.dart';
import 'package:kimo/features/settings/delete_account_screen.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/state/user_profile.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:kimo/widgets/kit/kimo_button.dart';

/// Hesap silme ekranı (Task 18). Silmenin kendisi yıkıcı ve yalnızca üretim
/// turunda tetikleniyor; ekranın KAPISI ise burada sabitleniyor:
///
/// 1. Takma ad eşleşmeden düğme kapalı — eşleşme büyük/küçük harfe ve
///    boşluğa duyarsız (kullanıcı "ada " yazınca kilitli kalmamalı).
/// 2. Sunucu reddederse ekran AÇIK kalıyor, sebep yazıyor, düğme yeniden
///    etkin. Sunucu kısmi başarıda hesabı silmiyor; kullanıcı "silindi mi?"
///    belirsizliğinde bırakılamaz.
void main() {
  late L10n l;
  setUpAll(() async => l = await L10n.delegate.load(const Locale('tr')));
  setUp(() => userProfile.setNicknameForTest('Ada'));
  tearDown(() {
    AccountRepository.deleteOverride = null;
    userProfile.setNicknameForTest(null);
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: AppTheme.light(),
        home: const DeleteAccountScreen(),
      ));

  Finder button() => find.widgetWithText(KimoButton, l.deleteAction);

  testWidgets('takma ad eşleşmeden düğme KAPALI', (WidgetTester tester) async {
    await pump(tester);
    expect(tester.widget<KimoButton>(button()).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Ad');
    await tester.pump();
    expect(tester.widget<KimoButton>(button()).onPressed, isNull);
  });

  testWidgets('eşleşme büyük/küçük harfe ve boşluğa DUYARSIZ',
      (WidgetTester tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '  aDa ');
    await tester.pump();
    expect(tester.widget<KimoButton>(button()).onPressed, isNotNull,
        reason: '"ada " yazan kullanıcı kilitli kalmamalı');
  });

  testWidgets('sunucu reddedince ekran açık, sebep yazıyor, düğme serbest',
      (WidgetTester tester) async {
    AccountRepository.deleteOverride = () async => throw Exception('503');
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();
    await tester.tap(button());
    await tester.pump(); // _running = true
    await tester.pump(); // catch dalı
    expect(find.byType(DeleteAccountScreen), findsOneWidget,
        reason: 'silinmemiş hesabın ekranı kapanmamalı');
    expect(find.text(l.deleteFailed), findsOneWidget);
    expect(tester.widget<KimoButton>(button()).onPressed, isNotNull);
  });

  testWidgets('başarı: silme çağrısı BİR kez yapılıyor ve ekran kapanıyor',
      (WidgetTester tester) async {
    int calls = 0;
    AccountRepository.deleteOverride = () async {
      calls++;
      return 0;
    };
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: Builder(
        builder: (BuildContext ctx) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(
                builder: (_) => const DeleteAccountScreen())),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();
    await tester.tap(button());
    await tester.pump();
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(DeleteAccountScreen), findsNothing);
    expect(find.text(l.deleteDone), findsOneWidget);
  });
}
