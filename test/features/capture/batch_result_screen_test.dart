import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/daily_state_repository.dart';
import 'package:kimo/data/photo_queue.dart';
import 'package:kimo/features/capture/batch_result_screen.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:kimo/widgets/kit/kimo_button.dart';

/// Parti sonuç ekranının özeti (Task 18 turu).
///
/// Sunucu konuyu ve şıkları çıkarmış, yalnız doğru şık eksik kalmışken özet
/// "2 okunamadı" yazıyordu — satırın kendisi şık seçiciyi gösterirken.
/// Sabitlenen: yalnız şıkkı eksik satır "şık bekliyor" sayılır, gerçekten
/// okunamayan "okunamadı"; şık bekleyen yoksa o parça hiç yazılmaz; halka
/// analizi bitmiş bütün satırları sayar; başka partinin kaydı görünmez.
///
/// Kuyruk diskte: yazma ve okuma `tester.runAsync` içinde
/// (bkz. pending_photos_screen_test).
void main() {
  late L10n l;
  late Directory dir;

  setUpAll(() async => l = await L10n.delegate.load(const Locale('tr')));
  setUp(() {
    dir = Directory.systemTemp.createTempSync('kimo-batch-');
    PhotoQueue.directoryOverride = dir;
    PhotoQueue.uidOverride = 'u1';
    photoQueue.debugResetCache();
    DailyStateRepository.readOverride = () async => null;
  });
  tearDown(() {
    PhotoQueue.directoryOverride = null;
    PhotoQueue.uidOverride = null;
    DailyStateRepository.readOverride = null;
    photoQueue.debugResetCache();
    dir.deleteSync(recursive: true);
  });

  Future<void> seed({required bool withAwaiting}) async {
    if (withAwaiting) {
      // Okundu: konu + şıklar var, doğru şık yok.
      await photoQueue.enqueue(
        bytes: Uint8List.fromList(<int>[1]),
        state: PhotoQueueState.needsUser,
        fields: <String, dynamic>{
          'subject': 'Fizik',
          'concept': 'Kuvvet ve Hareket',
          'labels': <String>['A', 'B', 'C', 'D', 'E'],
        },
        batchId: 'b1',
      );
    }
    // Gerçekten okunamadı: hiçbir alan yok.
    await photoQueue.enqueue(
      bytes: Uint8List.fromList(<int>[2]),
      state: PhotoQueueState.needsUser,
      batchId: 'b1',
    );
    // Başka parti: bu ekranda görünmemeli.
    await photoQueue.enqueue(
      bytes: Uint8List.fromList(<int>[3]),
      state: PhotoQueueState.needsUser,
      batchId: 'b2',
    );
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: const BatchResultScreen(batchId: 'b1'),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('yalnız şıkkı eksik satır "okunamadı" değil, "şık bekliyor"',
      (WidgetTester tester) async {
    await tester.runAsync(() => seed(withAwaiting: true));
    await pump(tester);

    expect(find.text(l.batchTitle(2)), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(
      find.text('${l.batchProgress(0, 0, 1)} · ${l.batchAwaiting(1)}'),
      findsOneWidget,
    );
    // Satır düzeyi: okunan satırda şık seçici, okunamayanda "Düzelt".
    expect(find.text(l.batchRowFix), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    // Hazır satır yok → onay kapalı.
    final KimoButton approve = tester.widget<KimoButton>(
        find.widgetWithText(KimoButton, l.batchApproveAll(0)));
    expect(approve.onPressed, isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('şık bekleyen yoksa özet yalnız üç parça',
      (WidgetTester tester) async {
    await tester.runAsync(() => seed(withAwaiting: false));
    await pump(tester);

    expect(find.text('1/1'), findsOneWidget);
    expect(find.text(l.batchProgress(0, 0, 1)), findsOneWidget);
    expect(find.textContaining(l.batchAwaiting(0)), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
