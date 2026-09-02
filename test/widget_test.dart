import 'package:ai_yks_coach/app.dart';
import 'package:ai_yks_coach/features/home/today_screen.dart';
import 'package:ai_yks_coach/features/league/league_screen.dart';
import 'package:ai_yks_coach/features/mistakes/mistakes_screen.dart';
import 'package:ai_yks_coach/features/profile/profile_screen.dart';
import 'package:ai_yks_coach/state/app_settings.dart';
import 'package:ai_yks_coach/widgets/kit/kimo_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kabuk testi: uygulama açılıyor mu ve navigasyon doğru mu?
///
/// Eski hâli sahte "Koç" sekmesine ve "Koç Baykuş" adına dayanıyordu; ikisi de
/// kaldırıldı (task kararı).
///
/// **Metne göre değil YAPIYA göre iddia ediyor.** Önceki sürümü "Günlük Tekrar
/// Hedefi" metnini arıyordu ve iki sorunu vardı: (1) o metin yeniden yazılan
/// "Bugün" ekranıyla birlikte değişti, (2) sekmeler `IndexedStack` içinde
/// canlı tutulduğu için görünmeyen sekmenin metinleri de ağaçta duruyor —
/// yani "sekme değişti" iddiası metinle kurulduğunda YANLIŞ geçerdi.
void main() {
  setUp(() async {
    // Ses eklentisi testte yok; tercih artık diske yazıldığı için sahte depo.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.sound_enabled': false,
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await appSettings.load();
  });

  /// Alt çubuktaki bir sekmeye dokunur.
  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(
      of: find.byType(KimoNavBar),
      matching: find.text(label),
    ));
    await tester.pumpAndSettle();
  }

  int selectedIndex(WidgetTester tester) =>
      tester.widget<KimoNavBar>(find.byType(KimoNavBar)).selectedIndex;

  testWidgets('Uygulama açılır ve dört sekme de kurulur',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AiYksCoachApp());
    await tester.pumpAndSettle();

    // Dördü de `IndexedStack` içinde canlı; hepsi hata vermeden kuruluyor.
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.byType(MistakesScreen), findsOneWidget);
    expect(find.byType(LeagueScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsOneWidget);

    expect(selectedIndex(tester), 0, reason: 'açılışta Bugün seçili');
  });

  testWidgets('Sekmeler arası geçiş seçili indeksi değiştirir',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AiYksCoachApp());
    await tester.pumpAndSettle();

    await tapTab(tester, 'Hatalarım');
    expect(selectedIndex(tester), 1);

    await tapTab(tester, 'Lig');
    expect(selectedIndex(tester), 2);

    await tapTab(tester, 'Profil');
    expect(selectedIndex(tester), 3);

    await tapTab(tester, 'Bugün');
    expect(selectedIndex(tester), 0);
  });

  testWidgets('Alt çubuk dört sekme + ortada kamera düğmesi taşır',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AiYksCoachApp());
    await tester.pumpAndSettle();

    final KimoNavBar bar = tester.widget<KimoNavBar>(find.byType(KimoNavBar));
    expect(
      bar.items.map((KimoNavItem i) => i.label).toList(),
      <String>['Bugün', 'Hatalarım', 'Lig', 'Profil'],
    );

    // Kamera sekme DEĞİL: dört sekmenin dışında, ayrı bir eylem.
    expect(bar.items.length, 4);
    expect(bar.captureLabel, isNotEmpty);

    // Kaldırılan sahte sekmeler geri gelmemeli.
    expect(find.text('Koç'), findsNothing);
    expect(find.text('Koç Baykuş'), findsNothing);
    expect(find.text('Sosyal'), findsNothing);
  });

  testWidgets('Varsayılan tema sistemi takip eder', (WidgetTester tester) async {
    await tester.pumpWidget(const AiYksCoachApp());
    await tester.pumpAndSettle();

    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(app.darkTheme, isNotNull, reason: 'koyu tema tanımlı olmalı');
    // Tek desteklenen dil Türkçe; İngilizce beyanı kaldırıldı.
    expect(app.supportedLocales.map((Locale l) => l.languageCode), <String>['tr']);
  });
}
