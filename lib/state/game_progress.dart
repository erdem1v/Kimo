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
}

final GameProgress gameProgress = GameProgress.instance;
