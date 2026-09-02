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
/// Hedefi" metnini arıyordu; o metin "Bugün" ekranı yeniden yazılınca değişti
/// ve test bir daha asla geçemezdi. Seçili sekmeyi artık `KimoNavBar`ın
/// `selectedIndex`i söylüyor: yeniden yazılan bir metne bağlı değil.
///
/// `IndexedStack` seçili olmayan çocukları OFFSTAGE işaretliyor ve `find.*`
/// varsayılan olarak onları atlıyor; dört ekranın da kurulduğunu doğrulamak
/// için `skipOffstage: false` gerekiyor.
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

  /// Uygulamayı kurar ve birkaç kare ilerletir.
  ///
  /// **`pumpAndSettle` KULLANILMIYOR.** Kimo sürekli animasyonlu (nefes 3,4 sn,
  /// göz kırpma 5 sn) ve boşta döngüsü hiç bitmiyor; `pumpAndSettle` "hiçbir
  /// animasyon kalmayana kadar" beklediği için asla dönmez ve test zaman
  /// aşımına uğrar. Sabit sayıda kare ilerletmek burada doğru olan.
  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(const AiYksCoachApp());
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 32));
  }

  /// Alt çubuktaki bir sekmeye dokunur.
  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(
      of: find.byType(KimoNavBar),
      matching: find.text(label),
    ));
    await tester.pump(const Duration(milliseconds: 32));
  }

  int selectedIndex(WidgetTester tester) =>
      tester.widget<KimoNavBar>(find.byType(KimoNavBar)).selectedIndex;

  testWidgets('Uygulama açılır ve dört sekme de kurulur',
      (WidgetTester tester) async {
    await boot(tester);

    // Dördü de `IndexedStack` içinde KURULUYOR (hata vermeden). Görünmeyen
    // üçü offstage olduğu için `skipOffstage: false` şart.
    expect(find.byType(TodayScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(MistakesScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(LeagueScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(ProfileScreen, skipOffstage: false), findsOneWidget);

    // Yalnızca seçili olan GÖRÜNÜR.
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);

    expect(selectedIndex(tester), 0, reason: 'açılışta Bugün seçili');
  });

  testWidgets('Sekmeler arası geçiş seçili indeksi değiştirir',
      (WidgetTester tester) async {
    await boot(tester);

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
    await boot(tester);

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
    await boot(tester);

    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(app.darkTheme, isNotNull, reason: 'koyu tema tanımlı olmalı');
    // Tek desteklenen dil Türkçe; İngilizce beyanı kaldırıldı.
    expect(app.supportedLocales.map((Locale l) => l.languageCode), <String>['tr']);
  });
}
