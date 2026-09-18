import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/sanction_repository.dart';
import 'package:kimo/features/settings/suspended_screen.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/theme/app_theme.dart';

/// Askı ekranı ve fotoğraf uyarısı sayfası (Task 18).
///
/// Ekran bir DUVAR değil: "Uygulamaya dön" çağıranın verdiği `onContinue`u
/// çağırmalı — aksi hâlde askıdaki kullanıcı arşivine bile ulaşamaz. Kalıcı
/// yasakta tarih UYDURULMUYOR; süreli askıda bitiş günü yazıyor. İtiraz
/// adresi derleme tanımıyla geliyor; testte yok, dolayısıyla itiraz düğmesi
/// "adres yok" demeli, sessizce hiçbir şey yapmamalı.
void main() {
  late L10n l;
  setUpAll(() async => l = await L10n.delegate.load(const Locale('tr')));

  Future<void> pump(WidgetTester tester, SanctionStatus s,
      {VoidCallback? onContinue}) =>
      tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: AppTheme.light(),
        home: SuspendedScreen(status: s, onContinue: onContinue ?? () {}),
      ));

  testWidgets('kalıcı yasak: kalıcı başlık, tarih UYDURULMUYOR',
      (WidgetTester tester) async {
    await pump(
        tester,
        SanctionStatus(
            suspended: true,
            permanent: true,
            until: DateTime(2030, 1, 1),
            reasonCode: 'abuse'));
    expect(find.text(l.suspendedTitlePermanent), findsOneWidget);
    expect(find.text(l.suspendedTitle), findsNothing);
    expect(find.text(l.suspendedNoEnd), findsOneWidget);
    expect(find.textContaining('01.01.2030'), findsNothing,
        reason: 'kalıcı yasakta bitiş tarihi gösterilmez');
    expect(find.text(l.suspendedReasonOther), findsOneWidget);
  });

  testWidgets('süreli askı: bitiş günü ve fotoğraf gerekçesi',
      (WidgetTester tester) async {
    await pump(
        tester,
        SanctionStatus(
            suspended: true,
            permanent: false,
            until: DateTime(2026, 10, 5),
            reasonCode: 'photo_repeat'));
    expect(find.text(l.suspendedTitle), findsOneWidget);
    expect(find.text(l.suspendedUntil('05.10.2026')), findsOneWidget);
    expect(find.text(l.suspendedReasonPhoto), findsOneWidget);
  });

  testWidgets('"Uygulamaya dön" onContinue çağırıyor — duvar değil',
      (WidgetTester tester) async {
    int continued = 0;
    await pump(
        tester,
        const SanctionStatus(suspended: true, permanent: false),
        onContinue: () => continued++);
    await tester.tap(find.text(l.suspendedContinue));
    await tester.pump();
    expect(continued, 1);
  });

  testWidgets('itiraz adresi yoksa SÖYLENİYOR, sessiz kalmıyor',
      (WidgetTester tester) async {
    await pump(tester, const SanctionStatus(suspended: true, permanent: false));
    await tester.tap(find.text(l.suspendedAppeal));
    await tester.pump();
    expect(find.text(l.suspendedAppealUnavailable), findsOneWidget);
  });

  group('fotoğraf uyarısı sayfası', () {
    Future<void> open(WidgetTester tester, PhotoWarning w) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: AppTheme.light(),
        home: Builder(
          builder: (BuildContext ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showPhotoWarning(ctx, w),
              child: const Text('aç'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
    }

    testWidgets('sertlik KAYIT ANINDAKİ sıradan seçiliyor',
        (WidgetTester tester) async {
      await open(tester,
          const PhotoWarning(id: 'w1', strikeNo: 1, activeCount: 3));
      expect(find.text(l.warningTitleGentle), findsOneWidget,
          reason: 'güncel sayaç 3 olsa da uyarı 1. ihlalin metnini taşımalı');
    });

    testWidgets('üçüncü ihlal askı tonunda', (WidgetTester tester) async {
      await open(tester,
          const PhotoWarning(id: 'w3', strikeNo: 3, activeCount: 3));
      expect(find.text(l.warningTitleSuspended), findsOneWidget);
    });
  });
}
