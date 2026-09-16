import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/features/capture/confirm_screen.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/models/models.dart';
import 'package:kimo/theme/app_theme.dart';

/// Onay ekranının Task 15'te kapatılan üç kusuru.
///
/// Üçü de AĞSIZ sınanabiliyor: ikisi çizim kararı, biri rota sözleşmesi.
/// Kaydetme yolunun kendisi Supabase istiyor ve burada kapsam dışı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late L10n l;

  setUpAll(() async {
    l = await L10n.delegate.load(const Locale('tr'));
  });

  /// Ekranı ÇEKİM AKIŞININ rotasıyla açar.
  ///
  /// `MaterialPageRoute<String>` bilinçli: ekranın sonuç sözleşmesi bu ve
  /// testin asıl işi o sözleşmenin iki yönde de tutmasını sınamak.
  Future<void> pumpConfirm(
    WidgetTester tester, {
    required QuestionAnalysis? analysis,
  }) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push<String>(
                MaterialPageRoute<String>(
                  builder: (_) => ConfirmMistakeScreen(analysis: analysis),
                ),
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    // `pumpAndSettle` DEĞİL: Kimo'nun nefes döngüsü hiç durmuyor (bkz.
    // `kimo_pose_test.dart`), yani ağaç asla "yerine oturmuyor". Rota
    // geçişini geçecek kadar sabit süre yeter.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  const QuestionAnalysis aiOk = QuestionAnalysis(
    ok: true,
    options: <QuestionOption>[
      QuestionOption(label: 'A', text: ''),
      QuestionOption(label: 'B', text: ''),
      QuestionOption(label: 'C', text: ''),
      QuestionOption(label: 'D', text: ''),
      QuestionOption(label: 'E', text: ''),
    ],
  );

  group('şık sayısı sorusu', () {
    testWidgets('yapay zekâ şıkları çıkardıysa HİÇ SORULMUYOR',
        (WidgetTester tester) async {
      // `ok` tanımı gereği "şıklar var" demek: sayı da etiketler de biliniyor.
      // Eskiden soru yine soruluyor, doğru çip önceden seçili geliyordu —
      // cevabı işaretlenmiş bir soru. Üstelik çipe dokunmak AI'nın
      // etiketlerini A–E ile değiştirip doğru şık işaretini düşürüyordu.
      await pumpConfirm(tester, analysis: aiOk);
      expect(find.text(l.confirmOptionCount), findsNothing);
      expect(find.text(l.confirmOptionCountValue(4)), findsNothing);
      // Şıkların KENDİSİ duruyor: soru kalkmıyor, yalnızca sayısı sorulmuyor.
      expect(find.text(l.confirmCorrectOption), findsOneWidget);
    });

    testWidgets('elle girişte SORULUYOR', (WidgetTester tester) async {
      await pumpConfirm(tester, analysis: null);
      expect(find.text(l.confirmOptionCount), findsOneWidget);
      expect(find.text(l.confirmOptionCountValue(4)), findsOneWidget);
      expect(find.text(l.confirmOptionCountValue(5)), findsOneWidget);
    });
  });

  testWidgets('vazgeç düğmesi ekranı GERÇEKTEN kapatıyor',
      (WidgetTester tester) async {
    // C1 REGRESYONU. Ekran `pop(false)` dönüyordu ama çekim akışı onu
    // `MaterialPageRoute<String>` olarak itiyor: `didPop`un eşdeğişken tip
    // denetimi patlıyor, hata jest işleyicisinde yutuluyor ve dokunuş hiçbir
    // şey yapmıyordu. Ekranın döndüğü DEĞER ile rotanın TİPİ tek sözleşme.
    await pumpConfirm(tester, analysis: aiOk);
    expect(find.text(l.confirmSave), findsOneWidget);

    await tester.tap(find.byTooltip(l.actionCancel));
    await tester.pump();
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text(l.confirmSave), findsNothing);
    expect(find.text('aç'), findsOneWidget);
  });

  testWidgets('konu satırı DERS SEÇİLMEDEN de açılıyor',
      (WidgetTester tester) async {
    // C6. Seçici dersi opsiyonel alıyor ve boşken bütün derslerde arıyor;
    // satır derse kilitliyken o yolun kapısı kapalıydı.
    await pumpConfirm(tester, analysis: null);
    await tester.tap(find.text(l.confirmTopicPick));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(l.topicPickerSearch), findsOneWidget);
  });
}
