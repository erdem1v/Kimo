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
  String? _avatarPath;

  /// Müfredat belirlendi mi?
  bool get isSet => _curriculum != null;

  /// Etkin müfredat (belirlenmediyse güvenli varsayılan: eski).
  String get curriculum => _curriculum ?? eski;

  int? get examYear => _examYear;
  String? get nickname => _nickname;
  Mascot? get mascot => _mascot;

  /// Profil fotoğrafının Storage yolu (yoksa maskot simgesi gösterilir).
  String? get avatarPath => _avatarPath;

  /// Yüklenen soruların soru havuzunda paylaşılmasına izin verildi mi?
  /// Karşılama akışında bir kez sorulur, profilden değiştirilebilir.
  bool get shareConsent => _shareConsent;

  /// Maskot hatırlatmaları açık mı? Bu anahtar yalnızca "hatırlat / hatırlatma"
  /// kararını taşır; hangi saatte ve hangi sessiz aralıkla hatırlatılacağı
  /// cihaz tercihidir ve `AppSettings` içinde durur.
  bool get notifyEnabled => _notifyEnabled;

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
    // Paylaşım onayı artık metadata'dan OKUNMUYOR — kaynağı `user_consents`
    // defteri (bkz. loadConsents). Buradaki değer yalnızca defter yüklenene
    // kadarki başlangıç durumu ve varsayılanı "onay yok".
    _shareConsent = false;
    _notifyEnabled = meta?['notify_enabled'] == true;
    final Object? a = meta?['avatar_path'];
    _avatarPath = (a is String && a.isNotEmpty) ? a : null;
    notifyListeners();
  }

  /// Profil fotoğrafının yolunu saklar. Asıl dosya ve `profiles.avatar_path`
  /// SocialRepository tarafından yazılır; burada yalnızca yerel kopyası tutulur
  /// (diğer cihazlarda da görünsün diye metadata'ya da yazılır).
  Future<void> setAvatarPath(String? path) async {
    _avatarPath = (path != null && path.isNotEmpty) ? path : null;
    notifyListeners();
    await _save(<String, dynamic>{'avatar_path': _avatarPath});
  }

  Future<void> setNotifyEnabled(bool value) async {
    _notifyEnabled = value;
    notifyListeners();
    await _save(<String, dynamic>{'notify_enabled': value});
  }

  /// Paylaşım onayını değiştirir.
  ///
  /// Onay artık auth metadata'sına DEĞİL, yalnızca ekleme yapılabilen
  /// `user_consents` defterine yazılıyor. Sebep: auth metadata tamamen
  /// kullanıcı-yazılabilir ve zaman damgası taşımıyor, yani onay geriye dönük
  /// değiştirilebiliyor ve ne zaman verildiği hiçbir yerde durmuyordu.
  /// Defterde UPDATE/DELETE hiçbir uygulama rolüne verilmiyor (bkz. 0037 göçü).
  ///
  /// Yerel alan yalnızca arayüz için tutuluyor; kaydın kaynağı defter.
  Future<void> setShareConsent(bool value) async {
    _shareConsent = value;
    notifyListeners();
    if (!SupabaseConfig.isConfigured) return;
    await Supabase.instance.client.rpc<void>(
      'record_consent',
      params: <String, dynamic>{'p_kind': 'share', 'p_granted': value},
    );
  }

  /// Onay defterindeki güncel değerleri yükler (oturum açılışında).
  ///
  /// Auth metadata'sındaki eski `share_consent` artık okunmuyor: yazılabilir
  /// olduğu için güvenilir bir kaynak değil.
  Future<void> loadConsents() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final List<Map<String, dynamic>> rows = await Supabase.instance.client
          .from('my_consents')
          .select('kind, granted');
      for (final Map<String, dynamic> r in rows) {
        if (r['kind'] == 'share') _shareConsent = r['granted'] == true;
      }
      notifyListeners();
    } catch (e) {
      // Çevrimdışı olabilir; yerel değer korunur.
      debugPrint('onay defteri okunamadı: $e');
    }
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
    _avatarPath = null;
    notifyListeners();
  }
}

final UserProfile userProfile = UserProfile.instance;
