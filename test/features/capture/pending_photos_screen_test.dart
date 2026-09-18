import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/photo_queue.dart';
import 'package:kimo/features/capture/pending_photos_screen.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:kimo/widgets/kit/kimo_button.dart';

/// Bekleyen fotoğraflar ekranı (Task 18). Kuyruk DİSKTE (kill'e dayanıklı,
/// bkz. photo_queue_test) ve ekranın tek kaynağı `photoQueue.list()`.
///
/// `testWidgets` sahte-zaman bölgesinde koşuyor; GERÇEK dosya G/Ç'si orada
/// hiç bitmiyor (test sonsuza kadar askıda kalıyor — bu dosyanın ilk sürümü
/// tam olarak böyle asıldı). Kuyruğa yazma ve ekranın diskten okuması
/// `tester.runAsync` içinde yapılıyor.
/// Sabitlenen: iki kayıt → iki kart (durum rozeti ve "Tamamla"/"Sil"),
/// boş kuyruk → boş durum metni; başka bir kullanıcının kaydı görünmez.
void main() {
  late L10n l;
  late Directory dir;

  setUpAll(() async => l = await L10n.delegate.load(const Locale('tr')));
  setUp(() {
    dir = Directory.systemTemp.createTempSync('kimo-pending-');
    PhotoQueue.directoryOverride = dir;
    PhotoQueue.uidOverride = 'u1';
    photoQueue.debugResetCache();
  });
  tearDown(() {
    PhotoQueue.directoryOverride = null;
    PhotoQueue.uidOverride = null;
    photoQueue.debugResetCache();
    dir.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: const PendingPhotosScreen(),
    ));
    // Ekranın `_load`u diski okuyor: gerçek zamanda tamamlansın.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('boş kuyruk: boş durum, kart yok', (WidgetTester tester) async {
    await pump(tester);
    expect(find.text(l.photoQueueEmpty), findsOneWidget);
    expect(find.widgetWithText(KimoButton, l.photoQueueComplete), findsNothing);
  });

  testWidgets('iki kayıt → iki kart, ikisinde de Tamamla ve Sil',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      await photoQueue.enqueue(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        state: PhotoQueueState.needsUser,
        fields: <String, dynamic>{'subject': 'Matematik', 'concept': 'Türev'},
      );
      await photoQueue.enqueue(
        bytes: Uint8List.fromList(<int>[4, 5, 6]),
        state: PhotoQueueState.needsAnalysis,
      );
    });
    await pump(tester);
    expect(find.text(l.photoQueueEmpty), findsNothing);
    expect(find.widgetWithText(KimoButton, l.photoQueueComplete), findsNWidgets(2));
    expect(find.widgetWithText(KimoButton, l.photoQueueDeleteTitle), findsNWidgets(2));
    expect(find.text(l.photoQueueStateNeedsUser), findsOneWidget);
    expect(find.text(l.photoQueueStateAnalyzing), findsOneWidget);
  });

  testWidgets('başka kullanıcının kaydı GÖRÜNMÜYOR', (WidgetTester tester) async {
    await tester.runAsync(() => photoQueue.enqueue(
          bytes: Uint8List.fromList(<int>[1]),
          state: PhotoQueueState.needsAnalysis,
        ));
    PhotoQueue.uidOverride = 'u2';
    photoQueue.debugResetCache();
    await pump(tester);
    expect(find.text(l.photoQueueEmpty), findsOneWidget,
        reason: 'aynı cihazda hesap değiştiren kullanıcı öncekinin fotoğrafını görmemeli');
  });
}
