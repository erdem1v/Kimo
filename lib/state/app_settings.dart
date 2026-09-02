import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cihaza ait tercihler. Sunucuda karşılığı yok ve olmamalı: tema, ses ve
/// bildirim saatleri kullanıcının **bu telefondaki** tercihi.
///
/// Hesap verisi (XP, seri, can, onay) buraya yazılmaz — o taraf sunucu
/// otoritesinde (bkz. Task 01).
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const String _kThemeMode = 'settings.theme_mode';
  static const String _kSound = 'settings.sound_enabled';
  static const String _kReviewHour = 'settings.review_hour';
  static const String _kStreakHour = 'settings.streak_hour';
  static const String _kQuietStart = 'settings.quiet_start';
  static const String _kQuietEnd = 'settings.quiet_end';

  /// Varsayılan hatırlatma saatleri. Bu değerler bugüne kadar koda gömülüydü;
  /// artık yalnızca varsayılan, kullanıcı değiştirebiliyor.
  static const int defaultReviewHour = 17;
  static const int defaultStreakHour = 20;
  static const int defaultQuietStart = 22;
  static const int defaultQuietEnd = 8;

  bool _loaded = false;
  ThemeMode _themeMode = ThemeMode.system;
  bool _soundEnabled = true;
  int _reviewHour = defaultReviewHour;
  int _streakHour = defaultStreakHour;
  int _quietStart = defaultQuietStart;
  int _quietEnd = defaultQuietEnd;

  /// Tercihler diskten okundu mu. Okunmadan önce varsayılanlar geçerlidir;
  /// ilk kare sistem temasıyla çizilir, bu doğru davranış.
  bool get isLoaded => _loaded;

  /// Varsayılan **sistem**: cihaz koyu moddaysa uygulama koyu açılır.
  /// Kullanıcı elle seçim yapana kadar sistemi takip eder.
  ThemeMode get themeMode => _themeMode;

  bool get soundEnabled => _soundEnabled;

  /// Günün tekrar hatırlatması (0–23).
  int get reviewHour => _reviewHour;

  /// Seri hatırlatması (0–23).
  int get streakHour => _streakHour;

  /// Sessiz aralığın başlangıç saati (dâhil).
  int get quietStart => _quietStart;

  /// Sessiz aralığın bitiş saati (hariç).
  int get quietEnd => _quietEnd;

  /// Sessiz aralık gece yarısını aşabilir (22 → 08). Tek yerde tanımlı olsun
  /// diye burada; bildirim servisi bunu çağırır, kendi eşiğini tutmaz.
  bool isQuietHour(int hour) {
    if (_quietStart == _quietEnd) return false;
    if (_quietStart < _quietEnd) {
      return hour >= _quietStart && hour < _quietEnd;
    }
    return hour >= _quietStart || hour < _quietEnd;
  }

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _themeMode = _decodeThemeMode(prefs.getString(_kThemeMode));
    _soundEnabled = prefs.getBool(_kSound) ?? true;
    _reviewHour = _clampHour(prefs.getInt(_kReviewHour), defaultReviewHour);
    _streakHour = _clampHour(prefs.getInt(_kStreakHour), defaultStreakHour);
    _quietStart = _clampHour(prefs.getInt(_kQuietStart), defaultQuietStart);
    _quietEnd = _clampHour(prefs.getInt(_kQuietEnd), defaultQuietEnd);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, _encodeThemeMode(mode));
  }

  Future<void> setSoundEnabled(bool value) async {
    if (_soundEnabled == value) return;
    _soundEnabled = value;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSound, value);
  }

  Future<void> setReviewHour(int hour) async {
    final int h = _clampHour(hour, defaultReviewHour);
    if (_reviewHour == h) return;
    _reviewHour = h;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kReviewHour, h);
  }

  Future<void> setStreakHour(int hour) async {
    final int h = _clampHour(hour, defaultStreakHour);
    if (_streakHour == h) return;
    _streakHour = h;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStreakHour, h);
  }

  Future<void> setQuietRange(int start, int end) async {
    final int s = _clampHour(start, defaultQuietStart);
    final int e = _clampHour(end, defaultQuietEnd);
    if (_quietStart == s && _quietEnd == e) return;
    _quietStart = s;
    _quietEnd = e;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kQuietStart, s);
    await prefs.setInt(_kQuietEnd, e);
  }

  static int _clampHour(int? value, int fallback) {
    if (value == null || value < 0 || value > 23) return fallback;
    return value;
  }

  static String _encodeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode _decodeThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

/// Uygulama genelinde tek örnek.
final AppSettings appSettings = AppSettings.instance;
