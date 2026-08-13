import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mascot.dart';
import '../services/supabase_config.dart';

/// Kullanıcının profil tercihleri: takma ad, sınav yılı → müfredat ve maskot
/// karakteri. Hepsi Supabase auth metadata'sında saklanır (cihazlar arası
/// senkron; ayrı tablo/RLS gerekmez).
///
/// 2026-2027 → eski müfredat · 2028 ve sonrası → maarif.
class UserProfile extends ChangeNotifier {
  UserProfile._();
  static final UserProfile instance = UserProfile._();

  static const String eski = 'eski';
  static const String maarif = 'maarif';

  String? _curriculum; // 'eski' | 'maarif' | null (henüz belirlenmedi)
  int? _examYear;
  String? _nickname;
  Mascot? _mascot;
  bool _shareConsent = false;
  bool _notifyEnabled = false;
  int _reviewHour = 17;
  int _streakHour = 20;

  /// Müfredat belirlendi mi?
  bool get isSet => _curriculum != null;

  /// Etkin müfredat (belirlenmediyse güvenli varsayılan: eski).
  String get curriculum => _curriculum ?? eski;

  int? get examYear => _examYear;
  String? get nickname => _nickname;
  Mascot? get mascot => _mascot;

  /// Yüklenen soruların soru havuzunda paylaşılmasına izin verildi mi?
  /// Karşılama akışında bir kez sorulur, profilden değiştirilebilir.
  bool get shareConsent => _shareConsent;

  /// Maskot hatırlatmaları açık mı, hangi saatlerde?
  bool get notifyEnabled => _notifyEnabled;
  int get reviewHour => _reviewHour;
  int get streakHour => _streakHour;

  /// Karşılama akışı tamamlandı mı? (takma ad + sınav yılı + maskot)
  bool get onboardingComplete =>
      _nickname != null &&
      _nickname!.isNotEmpty &&
      _curriculum != null &&
      _mascot != null;

  static String curriculumForYear(int year) => year >= 2028 ? maarif : eski;

  /// Oturumdaki kullanıcının metadata'sından yükler.
  void loadFromAuth() {
    if (!SupabaseConfig.isConfigured) return;
    final Map<String, dynamic>? meta =
        Supabase.instance.client.auth.currentUser?.userMetadata;
    final Object? c = meta?['curriculum'];
    final Object? y = meta?['exam_year'];
    final Object? n = meta?['nickname'] ?? meta?['display_name'];
    _curriculum = (c == eski || c == maarif) ? c as String : null;
    _examYear = y is int ? y : (y is num ? y.toInt() : null);
    _nickname = (n is String && n.trim().isNotEmpty) ? n.trim() : null;
    _mascot = Mascot.fromDb(meta?['mascot'] as String?);
    _shareConsent = meta?['share_consent'] == true;
    _notifyEnabled = meta?['notify_enabled'] == true;
    _reviewHour = _hour(meta?['notify_review_hour'], 17);
    _streakHour = _hour(meta?['notify_streak_hour'], 20);
    notifyListeners();
  }

  /// Sessiz saatlerin (22:00–08:00) dışına kırpar.
  static int _hour(Object? v, int fallback) {
    final int h = v is int ? v : (v is num ? v.toInt() : fallback);
    return (h < 8 || h > 21) ? fallback : h;
  }

  Future<void> setNotifyEnabled(bool value) async {
    _notifyEnabled = value;
    notifyListeners();
    await _save(<String, dynamic>{'notify_enabled': value});
  }

  Future<void> setNotifyHours({int? review, int? streak}) async {
    if (review != null) _reviewHour = _hour(review, _reviewHour);
    if (streak != null) _streakHour = _hour(streak, _streakHour);
    notifyListeners();
    await _save(<String, dynamic>{
      'notify_review_hour': _reviewHour,
      'notify_streak_hour': _streakHour,
    });
  }

  Future<void> setShareConsent(bool value) async {
    _shareConsent = value;
    notifyListeners();
    await _save(<String, dynamic>{'share_consent': value});
  }

  /// Sınav yılını kaydeder ve müfredatı buna göre belirler.
  Future<void> setExamYear(int year) async {
    _examYear = year;
    _curriculum = curriculumForYear(year);
    notifyListeners();
    await _save(<String, dynamic>{
      'curriculum': _curriculum,
      'exam_year': year,
    });
  }

  Future<void> setNickname(String nickname) async {
    final String value = nickname.trim();
    if (value.isEmpty) return;
    _nickname = value;
    notifyListeners();
    await _save(<String, dynamic>{'nickname': value, 'display_name': value});
  }

  Future<void> setMascot(Mascot mascot) async {
    _mascot = mascot;
    notifyListeners();
    await _save(<String, dynamic>{'mascot': mascot.dbValue});
  }

  Future<void> _save(Map<String, dynamic> data) async {
    if (!SupabaseConfig.isConfigured) return;
    await Supabase.instance.client.auth.updateUser(UserAttributes(data: data));
  }

  /// Oturum kapanınca temizle.
  void clear() {
    _curriculum = null;
    _examYear = null;
    _nickname = null;
    _mascot = null;
    notifyListeners();
  }
}

final UserProfile userProfile = UserProfile.instance;
