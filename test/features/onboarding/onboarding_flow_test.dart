import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/auth_repository.dart';
import 'package:kimo/data/daily_state_repository.dart';
import 'package:kimo/data/photo_queue.dart';
import 'package:kimo/features/onboarding/onboarding_flow.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:kimo/widgets/kit/kimo_button.dart';

/// Kurulum akışı (Task 18).
///
/// İKİ SÖZ: (1) adım sayısı oturuma göre — anonim kullanıcı kayıt adımını
/// görür ("/ 4"), giriş yapmış kullanıcı görmez ("/ 3"); (2) Android geri
/// tuşu bir ADIM geri götürür, uygulamadan ÇIKARMAZ (Task 17'nin `PopScope`
/// düzeltmesi — iOS simülatöründe donanım tuşu olmadığı için turda
/// doğrulanamıyordu; bu test o boşluğu kapatıyor: `PopScope` silinince
/// `maybePop` akışı kapatır ve "Adım 1" bir daha görünmez).
void main() {
  late L10n l;
  late Directory dir;

  setUpAll(() async => l = await L10n.delegate.load(const Locale('tr')));
  setUp(() {
    dir = Directory.systemTemp.createTempSync('kimo-onb-');
    PhotoQueue.directoryOverride = dir;
    PhotoQueue.uidOverride = 'u1';
    photoQueue.debugResetCache();
    DailyStateRepository.ageStatusOverride = () async =>
        const AgeStatus(birthYearSet: true, isMinor: false, birthYear: 2008);
  });
  tearDown(() {
    AuthRepository.isAnonymousOverride = null;
    DailyStateRepository.ageStatusOverride = null;
    PhotoQueue.directoryOverride = null;
    PhotoQueue.uidOverride = null;
    photoQueue.debugResetCache();
    dir.deleteSync(recursive: true);
  });

  late BuildContext flowContext;

  Future<void> pump(WidgetTester tester, {required bool anonymous}) async {
    AuthRepository.isAnonymousOverride = anonymous;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: Builder(builder: (BuildContext ctx) {
        flowContext = ctx;
        return OnboardingFlow(onDone: () {});
      }),
    ));
    // Akış kuyruğu diskten sayıyor (`loadPendingCount`) ve dikişler gerçek
    // Future döndürüyor: sahte-zaman bölgesinde asılı kalmasınlar.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('giriş yapmış kullanıcı: 3 adım, kayıt adımı yok',
      (WidgetTester tester) async {
    await pump(tester, anonymous: false);
    expect(find.text(l.onboardStep(1, 3)), findsOneWidget);
  });

  testWidgets('anonim kullanıcı: 4 adım (kayıt dâhil)',
      (WidgetTester tester) async {
    // Kuyrukta fotoğraf varsa akış çekim ekranını KENDİLİĞİNDEN açmıyor
    // (Task 14 · D1); testte de ağa çıkan o ekranı kurmamak için tohum.
    await tester.runAsync(() => photoQueue.enqueue(
          bytes: Uint8List.fromList(<int>[1]),
          state: PhotoQueueState.needsAnalysis,
        ));
    await pump(tester, anonymous: true);
    expect(find.text(l.onboardStep(1, 4)), findsOneWidget);
  });

  testWidgets('geri tuşu: ikinci adımdan BİRİNCİYE döner, akışı kapatmaz',
      (WidgetTester tester) async {
    await pump(tester, anonymous: false);
    // Yaş adımı sunucuda zaten kayıtlı (dikiş): "Devam et" açık.
    final Finder next = find.widgetWithText(KimoButton, l.actionContinue);
    expect(tester.widget<KimoButton>(next).onPressed, isNotNull);
    await tester.tap(next);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l.onboardStep(2, 3)), findsOneWidget);

    // Donanım geri tuşu = Navigator.maybePop. PopScope(canPop: false) bunu
    // yakalayıp bir adım geri götürmeli.
    // `maybePop` PopScope tarafından ele alındığında da `true` döner (rota
    // POP EDİLMEDİ, istek karşılandı); kanıt dönüş değeri değil, ekran.
    await Navigator.of(flowContext).maybePop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l.onboardStep(1, 3)), findsOneWidget,
        reason: 'geri tuşu bir adım geri götürmeli');
    expect(find.byType(OnboardingFlow), findsOneWidget);
  });

  testWidgets('ilk adımda geri tuşu akışa DOKUNMUYOR (kök davranışı)',
      (WidgetTester tester) async {
    await pump(tester, anonymous: false);
    await Navigator.of(flowContext).maybePop();
    await tester.pump();
    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(find.text(l.onboardStep(1, 3)), findsOneWidget);
  });
}
