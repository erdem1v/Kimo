import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/mistake_repository.dart';
import 'package:kimo/features/mistakes/mistakes_screen.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/models/models.dart';
import 'package:kimo/state/refresh_bus.dart';
import 'package:kimo/theme/app_theme.dart';

/// U6 — TAZELEME SESSİZ OLMALI.
///
/// Hatalarım `refreshBus`'ın her ping'inde yeniden yükleniyor: sekmeye her
/// dönüşte, her soru silmede, her tekrar bitişinde. Eskiden `_load` gövdeyi
/// tam ekran çemberle değiştiriyordu, yani liste sıfırdan kuruluyor ve
/// kaydırma konumu kayboluyordu — okuduğun yerden en başa fırlıyordun.
///
/// Bu testler AYIRT EDİCİ: ikinci yükleme ASKIDAYKEN iddia kuruluyor. Eski
/// davranışta o anda ekranda çemberden başka bir şey yok.
void main() {
  late L10n l;

  setUpAll(() async {
    l = await L10n.delegate.load(const Locale('tr'));
  });

  tearDown(() => MistakeRepository.fetchOverride = null);

  MistakeEntry entry(String concept) => MistakeEntry(
        subject: 'Matematik',
        concept: concept,
        note: '',
        date: DateTime(2026, 9, 1),
      );

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: AppTheme.light(),
        home: const MistakesScreen(),
      ));

  testWidgets('ilk yükleme çember gösteriyor, sonra liste', (WidgetTester tester) async {
    final Completer<List<MistakeEntry>> first = Completer<List<MistakeEntry>>();
    MistakeRepository.fetchOverride = () => first.future;

    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget,
        reason: 'gösterecek hiçbir şey yokken çember doğru');

    first.complete(<MistakeEntry>[entry('Türev')]);
    await tester.pumpAndSettle();
    expect(find.text('Türev'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('tazeleme askıdayken liste ekranda KALIYOR', (WidgetTester tester) async {
    MistakeRepository.fetchOverride =
        () async => <MistakeEntry>[entry('Türev')];
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('Türev'), findsOneWidget);

    // İkinci yükleme askıya alınıyor: `refreshBus` ping'i geldi, sunucu
    // henüz cevap vermedi. EKRAN BU ANDA NE GÖSTERİYOR?
    final Completer<List<MistakeEntry>> second = Completer<List<MistakeEntry>>();
    MistakeRepository.fetchOverride = () => second.future;
    refreshBus.ping();
    await tester.pump();

    expect(find.text('Türev'), findsOneWidget,
        reason: 'eldeki liste tazeleme boyunca ekranda kalmalı');
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'tam ekran çember listeyi söküyor, kaydırma konumu kayboluyor');

    second.complete(<MistakeEntry>[entry('İntegral')]);
    await tester.pumpAndSettle();
    expect(find.text('İntegral'), findsOneWidget);
    expect(find.text('Türev'), findsNothing);
  });

  testWidgets('düşen tazeleme dolu ekranı hata metniyle değiştirmiyor',
      (WidgetTester tester) async {
    MistakeRepository.fetchOverride =
        () async => <MistakeEntry>[entry('Türev')];
    await pump(tester);
    await tester.pumpAndSettle();

    MistakeRepository.fetchOverride = () async => throw Exception('ağ yok');
    refreshBus.ping();
    await tester.pumpAndSettle();

    expect(find.text('Türev'), findsOneWidget);
    expect(find.text(l.mistakesLoadFailed), findsNothing,
        reason: 'bayat liste, boş hata ekranından iyidir');
  });

  testWidgets('son 7 gün grafiği TAŞMIYOR', (WidgetTester tester) async {
    // Kapanış turunda ekranda "BOTTOM OVERFLOWED BY 10 PIXELS" şeridi çıktı:
    // haftalık sütun grafiği sabit 72 piksellik bir kutuya sığdırılmıştı ama
    // içerik (sayı + sütun + gün adı) ~82 piksel. Bu test o dalı KURUYOR —
    // eski testler tarihi geçmiş bir kayıt kullandığı için grafik hiç
    // çizilmiyor, "bu hafta kayıt yok" metnine düşüyordu.
    //
    // `flutter_test` taşmayı istisna olarak raporluyor; iddia gerekmiyor,
    // testin kendisi taşmada kırmızıya dönüyor.
    final DateTime today = DateTime.now();
    MistakeRepository.fetchOverride = () async => <MistakeEntry>[
          MistakeEntry(
            subject: 'Matematik',
            concept: 'Türev',
            note: '',
            date: today,
          ),
          MistakeEntry(
            subject: 'Matematik',
            concept: 'İntegral',
            note: '',
            date: today,
          ),
        ];
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text(l.mistakesWeekTitle), findsOneWidget);
  });

  testWidgets('ilk yükleme düşerse hata yüzeyi çıkıyor', (WidgetTester tester) async {
    MistakeRepository.fetchOverride = () async => throw Exception('ağ yok');
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text(l.mistakesLoadFailed), findsOneWidget);
  });
}
