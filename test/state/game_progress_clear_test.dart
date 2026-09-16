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
