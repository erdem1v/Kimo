import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_yks_coach/app.dart';

void main() {
  testWidgets('Bugünün Tekrarları ekranı yüklenir ve ilk soruyu gösterir',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AiYksCoachApp()));

    // Başlık, veri yüklenmeden önce de görünür.
    expect(find.text('Bugünün Tekrarları'), findsOneWidget);

    // Yüklenirken bir ilerleme göstergesi olmalı.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Mock repository gecikmesini geç.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // İlk soru yüklendiğinde "Cevabı Göster" butonu görünmeli.
    expect(find.text('Cevabı Göster'), findsOneWidget);

    // Cevabı göster ve doğru/yanlış butonlarının çıktığını doğrula.
    await tester.tap(find.text('Cevabı Göster'));
    await tester.pumpAndSettle();
    expect(find.text('Doğru bildim'), findsOneWidget);
    expect(find.text('Bilemedim'), findsOneWidget);
  });
}
