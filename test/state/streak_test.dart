import 'package:ai_yks_coach/state/game_progress.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seri mantığı: art arda günlerde çözünce büyür, gün atlanınca sıfırlanır,
/// aynı gün ikinci çözüm seriyi ikinci kez artırmaz.
void main() {
  final GameProgress g = gameProgress;

  DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime today() => dayOnly(DateTime.now());
  DateTime daysAgo(int n) => today().subtract(Duration(days: n));

  setUp(() {
    // Her testte temiz başla.
    g.hydrate(xp: 0, streak: 0, lastActive: null);
  });

  test('ilk aktivite seriyi 1 yapar', () {
    g.registerActivity();
    expect(g.streak, 1);
    expect(g.currentStreak, 1);
    expect(g.activeToday, isTrue);
  });

  test('aynı gün ikinci çözüm seriyi artırmaz', () {
    g.registerActivity();
    g.registerActivity();
    g.registerActivity();
    expect(g.streak, 1);
  });

  test('dün aktifse seri büyür', () {
    g.hydrate(xp: 0, streak: 4, lastActive: daysAgo(1));
    expect(g.currentStreak, 4); // dün aktif: seri hâlâ yaşıyor
    g.registerActivity();
    expect(g.streak, 5);
    expect(g.activeToday, isTrue);
  });

  test('bir gün atlanmışsa seri 1e sıfırlanır', () {
    g.hydrate(xp: 0, streak: 12, lastActive: daysAgo(2));
    expect(g.currentStreak, 0); // kırılmış: sunucudaki 12 gösterilmez
    g.registerActivity();
    expect(g.streak, 1);
  });

  test('dün aktifse ama bugün çözülmediyse seri risk altındadır', () {
    g.hydrate(xp: 0, streak: 3, lastActive: daysAgo(1));
    expect(g.activeToday, isFalse);
    expect(g.streakAtRisk, isTrue);

    g.registerActivity();
    expect(g.streakAtRisk, isFalse);
  });

  test('hiç aktivite yoksa seri 0 ve risk yok', () {
    expect(g.currentStreak, 0);
    expect(g.streakAtRisk, isFalse);
  });
}
