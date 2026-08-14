import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/social_repository.dart';
import '../models/social.dart';
import '../services/supabase_config.dart';

/// Oyunlaştırma durumu: XP, seviye, can, seri, elmas ve günlük tekrar
/// ilerlemesi. Ekranlar arasında paylaşılır (tekil [ChangeNotifier]).
/// XP, seri ve haftalık XP Supabase'de kalıcıdır (bkz. SocialRepository).
class GameProgress extends ChangeNotifier {
  GameProgress._();
  static final GameProgress instance = GameProgress._();

  int xp = 0;
  int hearts = 5;
  final int maxHearts = 5;
  int streak = 0;
  int gems = 0;

  /// Ligi sunucu belirler: her hafta grubunda ilk 5'e girersen yükselirsin.
  /// XP eşiğiyle lig atlama YOK.
  League league = League.bronz;

  static const int xpPerCorrect = 10;

  /// Günlük tekrar hedefi (üst sınır) ve hedefi tamamlama bonusu.
  static const int dailyReviewCap = 20;
  static const int dailyGoalBonus = 50;

  // Seviye sistemi kaldırıldı: ilerlemeyi toplam XP ve lig gösteriyor,
  // ayrıca bir "seviye" sayısı aynı şeyi üçüncü kez söylüyordu.

  // ------------------------------------------------------------------ seri
  // Seri, soru çözülen gün sayısıdır. Art arda günlerde çözülürse büyür,
  // bir gün atlanırsa sıfırlanır. Son aktif gün sunucuda saklanır.
  DateTime? _lastActive;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime? get lastActiveDate => _lastActive;

  /// Bugün seriyi sürdürecek aktivite yapıldı mı?
  bool get activeToday {
    final DateTime? d = _lastActive;
    return d != null && d == _dateOnly(DateTime.now());
  }

  /// Geçerli seri: son aktivite bugün ya da dünse yaşıyor, daha eskiyse
  /// kırılmıştır (sunucudaki sayı eski kalmış olabilir).
  int get currentStreak {
    final DateTime? d = _lastActive;
    if (d == null) return 0;
    final int gap = _dateOnly(DateTime.now()).difference(d).inDays;
    return gap <= 1 ? streak : 0;
  }

  /// Seri bugün henüz sürdürülmedi ama dün aktifti: risk altında.
  bool get streakAtRisk => currentStreak > 0 && !activeToday;

  /// Soru çözüldüğünde çağrılır (doğru/yanlış fark etmez). Günde bir kez sayar.
  void registerActivity() {
    final DateTime today = _dateOnly(DateTime.now());
    final DateTime? last = _lastActive;
    if (last == today) return; // bugün zaten sayıldı
    if (last != null && today.difference(last).inDays == 1) {
      streak += 1; // dün de aktiftin: seri büyüdü
    } else {
      streak = 1; // ilk gün ya da seri kırılmış
    }
    _lastActive = today;
    notifyListeners();
    _scheduleSync();
  }

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
    registerActivity();
  }

  /// Bu haftaki XP — lig içi sıralamayı belirler, pazartesi sıfırlanır.
  int weeklyXp = 0;
  DateTime? _weekStart;

  void _rollWeek() {
    final DateTime current = weekStart(DateTime.now());
    if (_weekStart != current) {
      _weekStart = current;
      weeklyXp = 0;
    }
  }

  void addXp(int amount) {
    _rollWeek();
    xp += amount;
    weeklyXp += amount;
    notifyListeners();
    _scheduleSync();
  }

  /// Sunucudaki değerlerle başlat (oturum açılışında).
  void hydrate({
    required int xp,
    required int streak,
    int weeklyXp = 0,
    DateTime? lastActive,
    League? league,
  }) {
    this.xp = xp;
    this.streak = streak;
    if (league != null) this.league = league;
    _weekStart = weekStart(DateTime.now());
    this.weeklyXp = weeklyXp;
    _lastActive = lastActive == null ? null : _dateOnly(lastActive);
    notifyListeners();
  }

  // XP her doğru cevapta artıyor; her seferinde ağ isteği atmamak için
  // kısa bir gecikmeyle toplu kaydederiz.
  Timer? _syncTimer;

  void _scheduleSync() {
    if (!SupabaseConfig.isConfigured) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 2), () {
      socialRepository.syncStats(
        xp: xp,
        streak: streak,
        weeklyXp: weeklyXp,
        weekStartDate: _weekStart ?? weekStart(DateTime.now()),
        lastActiveDate: _lastActive,
      );
    });
  }

  /// Günlük hedef bonusunu günde yalnızca bir kez verir; verdiyse true döner.
  bool claimDailyGoal(int bonus) {
    if (dailyGoalReached) return false;
    final DateTime n = DateTime.now();
    _lastGoalDate = DateTime(n.year, n.month, n.day);
    xp += bonus;
    notifyListeners();
    _scheduleSync();
    return true;
  }

  void refillHearts() {
    hearts = maxHearts;
    notifyListeners();
  }
}

final GameProgress gameProgress = GameProgress.instance;
