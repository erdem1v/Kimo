import 'package:flutter/foundation.dart';

/// Oyunlaştırma durumu: XP, seviye, can, seri, elmas ve günlük tekrar
/// ilerlemesi. Ekranlar arasında paylaşılır (tekil [ChangeNotifier]).
/// Not: şu an yereldir (uygulama kapanınca sıfırlanır); ileride Supabase'e
/// taşınacak.
class GameProgress extends ChangeNotifier {
  GameProgress._();
  static final GameProgress instance = GameProgress._();

  int xp = 1240;
  int hearts = 5;
  final int maxHearts = 5;
  int streak = 12;
  int gems = 335;

  static const int xpPerLevel = 500;
  static const int xpPerCorrect = 10;

  /// Günlük tekrar hedefi (üst sınır) ve hedefi tamamlama bonusu.
  static const int dailyReviewCap = 20;
  static const int dailyGoalBonus = 50;

  int get level => xp ~/ xpPerLevel + 1;
  int get xpIntoLevel => xp % xpPerLevel;
  double get levelProgress => xpIntoLevel / xpPerLevel;

  // --- Günlük tekrar ilerlemesi (yerel, gün değişince sıfırlanır) ---
  int dailyReviewsDone = 0;
  // Bugün yapılmayı bekleyen (planı gelmiş) tekrar sayısı; ekranlar yükleyince set eder.
  int _dueRemaining = 0;
  DateTime? _reviewDay;
  DateTime? _lastGoalDate;

  void _rollDay() {
    final DateTime n = DateTime.now();
    final DateTime today = DateTime(n.year, n.month, n.day);
    if (_reviewDay != today) {
      _reviewDay = today;
      dailyReviewsDone = 0;
      _dueRemaining = 0;
    }
  }

  /// Bugünün toplam hedefi = yapılan + kalan (üst sınır: dailyReviewCap).
  /// Kalan bilinmiyorsa (henüz yüklenmediyse) 0 olur.
  int get dailyTarget {
    final int total = dailyReviewsDone + _dueRemaining;
    return total > dailyReviewCap ? dailyReviewCap : total;
  }

  /// Ekranlar bugünün "kalan" (planı gelmiş, henüz yapılmamış) tekrar sayısını
  /// yükleyince çağırır. Böylece hedef gerçek soru sayısını yansıtır.
  void setDueRemaining(int remaining) {
    _rollDay();
    _dueRemaining = remaining < 0 ? 0 : remaining;
    notifyListeners();
  }

  /// Bugün yapılan tekrar sayısını DB'den gelen değerle senkronlar (uygulama
  /// kapanıp açılınca "bugün X/20" geri gelsin). Yalnızca yukarı doğru günceller
  /// ki henüz DB'ye yazılmamış (fire-and-forget) cevaplar geri sayılmasın.
  void syncDailyDone(int dbCount) {
    _rollDay();
    if (dbCount > dailyReviewsDone) {
      dailyReviewsDone = dbCount;
      notifyListeners();
    }
  }

  /// Günlük hedef bugün alındı mı?
  bool get dailyGoalReached {
    final DateTime n = DateTime.now();
    return _lastGoalDate != null &&
        _lastGoalDate!.year == n.year &&
        _lastGoalDate!.month == n.month &&
        _lastGoalDate!.day == n.day;
  }

  double get dailyProgress {
    if (dailyGoalReached) return 1;
    final int t = dailyTarget;
    if (t == 0) return 0;
    return (dailyReviewsDone / t).clamp(0, 1).toDouble();
  }

  /// Bir tekrar cevaplandığında (doğru/yanlış fark etmez) çağrılır.
  void recordReview() {
    _rollDay();
    dailyReviewsDone++;
    if (_dueRemaining > 0) _dueRemaining--;
    notifyListeners();
  }

  void addXp(int amount) {
    xp += amount;
    notifyListeners();
  }

  /// Günlük hedef bonusunu günde yalnızca bir kez verir; verdiyse true döner.
  bool claimDailyGoal(int bonus) {
    if (dailyGoalReached) return false;
    final DateTime n = DateTime.now();
    _lastGoalDate = DateTime(n.year, n.month, n.day);
    xp += bonus;
    notifyListeners();
    return true;
  }

  void refillHearts() {
    hearts = maxHearts;
    notifyListeners();
  }
}

final GameProgress gameProgress = GameProgress.instance;
