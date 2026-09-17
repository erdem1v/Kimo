import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/state/game_progress.dart';

/// Oturum kapanınca ilerleme sıfırlanıyor mu (Task 14).
///
/// NEDEN BU TEST VAR: `AuthGate` çıkışta `userProfile`, `submissionQueue` ve
/// `photoQueue`u temizliyordu ama `gameProgress`i temizlemiyordu. Aynı cihazda
/// açılan İKİNCİ hesap, öncekinin XP'sini, serisini ve günlük sayacını
/// görüyordu.
///
/// KENDİLİĞİNDEN DÜZELMİYORDU, testin asıl konusu bu: `syncDailyDone` yalnızca
/// YUKARI hareket ediyor (`if (dbCount > dailyReviewsDone)`), yani A'nın 5'i
/// B'nin 0'ıyla değiştirilemiyor. Aşağıdaki son iddia tam olarak onu tutuyor.
void main() {
  _dailyGoalFromServerTests();
  test('clear() bütün ilerleme durumunu sıfırlıyor', () {
    final GameProgress g = GameProgress.instance;
    g.hydrate(xp: 4200, streak: 9, lastActive: DateTime(2026, 9, 15));
    g.syncDailyDone(5);

    expect(g.xp, 4200);
    expect(g.streak, 9);
    expect(g.dailyReviewsDone, 5);

    g.clear();

    expect(g.xp, 0, reason: 'XP sonraki hesaba sızmamalı');
    expect(g.streak, 0, reason: 'seri sonraki hesaba sızmamalı');
    expect(g.dailyReviewsDone, 0, reason: 'günlük sayaç sonraki hesaba sızmamalı');
    expect(g.lastActiveDate, isNull);
  });

  test('clear() OLMADAN günlük sayaç aşağı inmiyor — sızıntının mekanizması', () {
    final GameProgress g = GameProgress.instance;
    g.clear();
    g.syncDailyDone(5);
    expect(g.dailyReviewsDone, 5);

    // Yeni hesabın sunucu sayısı 0; `syncDailyDone` tek yönlü olduğu için
    // ESKİ değer duruyor. Sıfırlamanın tek yolu `clear()`.
    g.syncDailyDone(0);
    expect(g.dailyReviewsDone, 5,
        reason: 'tek yönlü senkron eski hesabın sayısını silemiyor');

    g.clear();
    expect(g.dailyReviewsDone, 0);
  });
}

/// Günlük hedef ödülünün günü SUNUCUDAN geliyor (Task 17 · 0099).
void _dailyGoalFromServerTests() {
  group('günlük hedef günü sunucudan', () {
    setUp(gameProgress.clear);

    test('sunucu "bugün alındı" derse istemci ikinci kez istemiyor', () {
      // ESKİDEN: `_lastGoalDate` yalnızca oturum-içiydi ve `clear()` onu
      // çıkışta sıfırlıyordu. Yeniden kurulumda ya da ikinci cihazda istemci
      // "ödül alınmadı" sanıyor, `claim_daily_goal` sessizce sıfır ödül
      // döndürüyordu — hata ATMADIĞI için geri alma dalı da çalışmıyordu.
      final DateTime bugun = DateTime(2026, 9, 17);
      gameProgress.syncFromDailyState(
        xp: 100,
        weeklyXp: 10,
        streak: 1,
        serverToday: bugun,
        dailyGoalDate: bugun,
      );
      expect(gameProgress.dailyGoalReached, isTrue);
      expect(gameProgress.claimDailyGoal(50), isFalse,
          reason: 'sunucu almış diyorsa yerel ikinci kez eklemez');
    });

    test('sunucu boş dönerse ödül İSTENEBİLİR kalıyor', () {
      gameProgress.syncFromDailyState(
        xp: 100,
        weeklyXp: 10,
        streak: 1,
        serverToday: DateTime(2026, 9, 17),
      );
      expect(gameProgress.dailyGoalReached, isFalse);
      expect(gameProgress.claimDailyGoal(50), isTrue);
    });

    test('DÜNKÜ ödül bugünü kapatmıyor', () {
      gameProgress.syncFromDailyState(
        xp: 100,
        weeklyXp: 10,
        streak: 1,
        serverToday: DateTime(2026, 9, 17),
        dailyGoalDate: DateTime(2026, 9, 16),
      );
      expect(gameProgress.dailyGoalReached, isFalse);
    });
  });
}
