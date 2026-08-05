import 'package:ai_yks_coach/app.dart';
import 'package:ai_yks_coach/services/sound_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Uygulama açılır ve sekmeler arası geçiş çalışır',
      (WidgetTester tester) async {
    // Testte ses eklentisi olmadığı için sesi kapat.
    sound.enabled = false;

    await tester.pumpWidget(const AiYksCoachApp());
    await tester.pump();

    // Başlangıçta "Bugün" sekmesi: günlük hedef kartı görünür.
    expect(find.text('Günlük Tekrar Hedefi'), findsOneWidget);
    // Sohbet ekranı henüz seçili değil (offstage).
    expect(find.text('Koç Baykuş'), findsNothing);

    // Alt navigasyondan "Koç" sekmesine geç.
    await tester.tap(find.text('Koç'));
    await tester.pumpAndSettle();
    expect(find.text('Koç Baykuş'), findsOneWidget);

    // "Bugün" sekmesine geri dön.
    await tester.tap(find.text('Bugün'));
    await tester.pumpAndSettle();
    expect(find.text('Günlük Tekrar Hedefi'), findsOneWidget);
  });
}
