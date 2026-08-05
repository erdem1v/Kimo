import 'package:flutter/foundation.dart';

/// Oyunlaştırma durumu: XP, seviye, can, seri ve elmas. Ekranlar arasında
/// paylaşılır. Basit tutmak için tekil (singleton) bir [ChangeNotifier].
class GameProgress extends ChangeNotifier {
  GameProgress._();
  static final GameProgress instance = GameProgress._();

  int xp = 1240;
  int hearts = 5;
  final int maxHearts = 5;
  int streak = 12;
  int gems = 335;
  int dailyDone = 3;
  final int dailyGoal = 10;

  static const int xpPerLevel = 500;
  static const int xpPerCorrect = 10;

  /// Günlük tekrar hedefi (üst sınır) ve hedefi tamamlama bonusu.
  static const int dailyReviewCap = 20;
  static const int dailyGoalBonus = 50;

  int get level => xp ~/ xpPerLevel + 1;
  int get xpIntoLevel => xp % xpPerLevel;
  double get levelProgress => xpIntoLevel / xpPerLevel;
  double get dailyProgress => (dailyDone / dailyGoal).clamp(0, 1).toDouble();

  /// Bir soru cevaplandığında çağrılır. Doğruda XP ve günlük hedef artar,
  /// yanlışta can azalır.
  void answer({required bool correct}) {
    if (correct) {
      xp += xpPerCorrect;
      dailyDone++;
    } else if (hearts > 0) {
      hearts--;
    }
    notifyListeners();
  }

  void refillHearts() {
    hearts = maxHearts;
    notifyListeners();
  }

  void addXp(int amount) {
    xp += amount;
    notifyListeners();
  }

  DateTime? _lastGoalDate;

  /// Günlük hedef bonusunu günde yalnızca bir kez verir; verdiyse true döner.
  bool claimDailyGoal(int bonus) {
    final DateTime now = DateTime.now();
    final bool alreadyToday = _lastGoalDate != null &&
        _lastGoalDate!.year == now.year &&
        _lastGoalDate!.month == now.month &&
        _lastGoalDate!.day == now.day;
    if (alreadyToday) return false;
    _lastGoalDate = DateTime(now.year, now.month, now.day);
    xp += bonus;
    notifyListeners();
    return true;
  }
}

final GameProgress gameProgress = GameProgress.instance;
