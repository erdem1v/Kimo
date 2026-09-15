import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/features/inbox/send_flow.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:kimo/widgets/kit/kimo_button.dart';

/// Gönderme akışının giriş sayfası (Tur 7 · n5).
///
/// BU DOSYANIN KONUSU TEK BİR TASARIM KARARI: "Kapat" AYRI BİR SATIR olarak
/// duruyor mu. Apple HIG action sheet için iptali ZORUNLU kılıyor (en fazla
/// 3 ek seçenek + Cancel); Material 3'te kapanma scrim/geri tuşuyla da mümkün
/// ama WCAG 2.5.1 (A) ve 2.5.7 (AA) DOKUNULABİLİR bir kapatma hedefi istiyor.
/// Tek widget iki platformda aynı kalıyor ve ikisini birden karşılıyor.
void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    int archiveCount = 247,
  }) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: Scaffold(
        body: SendEntrySheetBody(
          friendId: 'f1',
          friendName: 'Mert',
          archiveCount: archiveCount,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 32));
  }

  testWidgets('üç seçenek: arşivden seç · yeni çek · KAPAT',
      (WidgetTester tester) async {
    await pumpSheet(tester);
    expect(find.text('Arşivinden seç'), findsOneWidget);
    expect(find.text('Yeni soru çek'), findsOneWidget);
    // Ayrı bir satır olarak KAPAT: dokunulabilir kapatma hedefi.
    expect(find.text('Kapat'), findsOneWidget);
    expect(find.byType(KimoButton), findsOneWidget);
  });

  testWidgets('başlıkta ALICININ adı var — akış arkadaş-önce',
      (WidgetTester tester) async {
    await pumpSheet(tester);
    // Alıcı sabit; seçilecek olan soru. Kullanıcıya iki kez seçim
    // yaptırılmıyor.
    expect(find.textContaining('Mert'), findsWidgets);
  });

  testWidgets('arşiv sayısı alt metinde görünüyor',
      (WidgetTester tester) async {
    await pumpSheet(tester);
    expect(find.textContaining('247'), findsOneWidget);
  });

  testWidgets('arşiv BOŞSA sayı yerine boş durumu söylüyor',
      (WidgetTester tester) async {
    await pumpSheet(tester, archiveCount: 0);
    expect(find.text('Arşivin boş'), findsOneWidget);
    // Seçenek yine GÖRÜNÜYOR: gizlemek "sorum nerede?" sorusunu üretirdi;
    // dokununca boş durum ekranı ekleme eylemine götürüyor.
    expect(find.text('Arşivinden seç'), findsOneWidget);
  });
}
