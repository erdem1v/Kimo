import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_config.dart';

/// Kullanıcının müfredat tercihi. Sınav yılına göre eski (2018) veya maarif
/// (Türkiye Yüzyılı Maarif Modeli) seçilir ve Supabase auth metadata'sında
/// saklanır (cihazlar arası senkron; ayrı tablo/RLS gerekmez).
///
/// 2026-2027 → eski · 2028 ve sonrası → maarif.
class UserProfile extends ChangeNotifier {
  UserProfile._();
  static final UserProfile instance = UserProfile._();

  static const String eski = 'eski';
  static const String maarif = 'maarif';

  String? _curriculum; // 'eski' | 'maarif' | null (henüz belirlenmedi)
  int? _examYear;

  /// Müfredat belirlendi mi? (false ise ilk açılışta sorulmalı.)
  bool get isSet => _curriculum != null;

  /// Etkin müfredat (belirlenmediyse güvenli varsayılan: eski).
  String get curriculum => _curriculum ?? eski;

  int? get examYear => _examYear;

  static String curriculumForYear(int year) => year >= 2028 ? maarif : eski;

  /// Oturumdaki kullanıcının metadata'sından yükler.
  void loadFromAuth() {
    if (!SupabaseConfig.isConfigured) return;
    final Map<String, dynamic>? meta =
        Supabase.instance.client.auth.currentUser?.userMetadata;
    final Object? c = meta?['curriculum'];
    final Object? y = meta?['exam_year'];
    _curriculum = (c == eski || c == maarif) ? c as String : null;
    _examYear = y is int ? y : (y is num ? y.toInt() : null);
    notifyListeners();
  }

  /// Sınav yılını kaydeder ve müfredatı buna göre belirler.
  Future<void> setExamYear(int year) async {
    _examYear = year;
    _curriculum = curriculumForYear(year);
    notifyListeners();
    if (SupabaseConfig.isConfigured) {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: <String, dynamic>{
          'curriculum': _curriculum,
          'exam_year': year,
        }),
      );
    }
  }

  /// Oturum kapanınca temizle.
  void clear() {
    _curriculum = null;
    _examYear = null;
    notifyListeners();
  }
}

final UserProfile userProfile = UserProfile.instance;
