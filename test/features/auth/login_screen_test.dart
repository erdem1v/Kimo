import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/auth_repository.dart';
import 'package:kimo/features/auth/login_screen.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:kimo/widgets/kit/kimo_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Giriş ekranı (Task 18). Tur bu formu klavye güvenilmezliği yüzünden
/// gezemiyor; sunucu tarafını `test_e2e/auth_claims` kapatıyor. Burada
/// sabitlenen şey ekranın kendisi: BAŞARISIZ giriş sonrası düğme YENİDEN
/// ETKİN ve kullanıcıya sebep söyleniyor. Task 15'in C4 sınıfı ("sonsuz
/// meşgul düğme") — `finally` bloğu kaldırılınca bu dosya kırmızıya dönüyor.
void main() {
  late L10n l;
  setUpAll(() async => l = await L10n.delegate.load(const Locale('tr')));
  tearDown(() => AuthRepository.signInOverride = null);

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: AppTheme.light(),
        home: const LoginScreen(),
      ));

  Finder button() => find.widgetWithText(KimoButton, l.signInAction);

  testWidgets('boş alanla giriş: sebep yazıyor, ağa çıkılmıyor',
      (WidgetTester tester) async {
    int calls = 0;
    AuthRepository.signInOverride =
        ({required String email, required String password}) async => calls++;
    await pump(tester);
    await tester.tap(button());
    await tester.pump();
    expect(find.text(l.signInFailed), findsOneWidget);
    expect(calls, 0, reason: 'boş alanla sunucuya gidilmemeli');
  });

  testWidgets('reddedilen giriş: sebep yazıyor VE düğme yeniden etkin',
      (WidgetTester tester) async {
    AuthRepository.signInOverride =
        ({required String email, required String password}) async =>
            throw const AuthException('Invalid login credentials');
    await pump(tester);
    await tester.enterText(find.byType(TextField).at(0), 'ada@kimo.test');
    await tester.enterText(find.byType(TextField).at(1), 'yanlis');
    await tester.tap(button());
    await tester.pump(); // _loading = true
    await tester.pump(); // seam fırlattı, finally çalıştı
    expect(find.text(l.signInFailed), findsOneWidget);
    expect(tester.widget<KimoButton>(button()).onPressed, isNotNull,
        reason: 'düğme meşgulde takılı kalırsa kullanıcı bir daha deneyemez');
  });

  testWidgets('beklenmeyen hata da düğmeyi serbest bırakıyor',
      (WidgetTester tester) async {
    AuthRepository.signInOverride =
        ({required String email, required String password}) async =>
            throw StateError('ağ yok');
    await pump(tester);
    await tester.enterText(find.byType(TextField).at(0), 'ada@kimo.test');
    await tester.enterText(find.byType(TextField).at(1), 'x');
    await tester.tap(button());
    await tester.pump();
    await tester.pump();
    expect(find.text(l.errorGeneric), findsOneWidget);
    expect(tester.widget<KimoButton>(button()).onPressed, isNotNull);
  });
}
