import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/social.dart';

/// Kullanıcının günlük durumu — HUD'un tek kaynağı.
///
/// Kalan can (AI okutma hakkı) SAKLANMIYOR, sunucuda türetiliyor: gün
/// anahtarı Europe/Istanbul takviminden geliyor, sayaç o günün satırından
/// okunuyor. Cihaz saatini değiştiren kullanıcı ek hak alamıyor ve istemcide
/// hiçbir zamanlayıcı yok.
@immutable
class DailyState {
  const DailyState({
    required this.aiLeft,
    required this.aiQuota,
    required this.aiResetsAt,
    required this.gems,
    required this.xp,
    required this.streak,
    required this.weeklyXp,
    required this.league,
    this.lastActivityDate,
    this.serverToday,
    this.reviewedTodayCount = 0,
    this.dueCount = 0,
    this.unsolvedReceivedCount = 0,
  });

  /// Bugün kalan yapay zekâ okutma hakkı.
  final int aiLeft;

  /// Günlük hak sayısı (sunucudaki `daily_ai_quota`).
  final int aiQuota;

  /// Hakların tazeleneceği an. Arayüzde geri sayım GÖSTERİLMİYOR; yalnızca
  /// "yarın yenilenecek" bilgisi için (tasarım kararı).
  final DateTime? aiResetsAt;

  final int gems;
  final int xp;

  /// ETKİN seri — sunucu kapıladı (Task 03): kopmuş seri artık 0 gelir.
  final int streak;
  final int weeklyXp;
  final League league;

  /// Sunucudaki son aktivite günü; "bugün aktif miyim" artık cihaz saatinden
  /// değil bundan türetiliyor.
  final DateTime? lastActivityDate;

  /// Sunucunun (Europe/Istanbul) bugünü. Günün tek tanımı bu.
  final DateTime? serverToday;

  /// Istanbul gününe göre bugün cevaplanmış tekrar sayısı (sunucu sayıyor;
  /// eski istemci sayımı gün sınırını 03:00'a kaydırıyordu).
  final int reviewedTodayCount;

  /// Vadesi gelmiş tekrar sayısı.
  final int dueCount;

  /// Arkadaşlardan gelen, çözülmemiş soru sayısı (gelen kutusu süzgeçleriyle).
  final int unsolvedReceivedCount;

  bool get hasAi => aiLeft > 0;

  /// Sunucuya göre bugün aktif miyim (seri bugün işlendi mi).
  bool get activeToday =>
      lastActivityDate != null &&
      serverToday != null &&
      !lastActivityDate!.isBefore(serverToday!);

  /// Seviye XP'den TÜRETİLİR; sunucuda ayrı bir sütun yok.
  ///
  /// Her 1000 XP bir seviye. Tasarımdaki "Seviye 7 · 860/1000" göstergesi bu
  /// formülün karşılığı.
  int get level => xp ~/ xpPerLevel + 1;

  /// Bu seviyede kazanılmış XP (0–999).
  int get levelProgress => xp % xpPerLevel;

  static const int xpPerLevel = 1000;

  factory DailyState.fromRow(Map<String, dynamic> row) {
    return DailyState(
      aiLeft: (row['ai_left'] as num?)?.toInt() ?? 0,
      aiQuota: (row['ai_quota'] as num?)?.toInt() ?? 5,
      aiResetsAt: row['ai_resets_at'] is String
          ? DateTime.tryParse(row['ai_resets_at'] as String)
          : null,
      gems: (row['gems'] as num?)?.toInt() ?? 0,
      xp: (row['xp'] as num?)?.toInt() ?? 0,
      streak: (row['streak'] as num?)?.toInt() ?? 0,
      weeklyXp: (row['weekly_xp'] as num?)?.toInt() ?? 0,
      league: League.fromDb(row['league'] as String?),
      lastActivityDate: row['last_activity_date'] is String
          ? DateTime.tryParse(row['last_activity_date'] as String)
          : null,
      serverToday: row['today'] is String
          ? DateTime.tryParse(row['today'] as String)
          : null,
      reviewedTodayCount: (row['reviewed_today_count'] as num?)?.toInt() ?? 0,
      dueCount: (row['due_count'] as num?)?.toInt() ?? 0,
      unsolvedReceivedCount:
          (row['unsolved_received_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Yaş kapısının durumu.
///
/// Yaşın KENDİSİNİ taşımıyor: arayüzün ihtiyacı olan tek şey yılın yazılıp
/// yazılmadığı ve (ayarlar satırı için) reşitlik.
///
/// Task 07: `GuardianStatus`ın yerini aldı. Veli onayı rejimi kaldırıldığı için
/// `consentGranted`, `guardianEmail` ve `canAddFriends` alanları düştü —
/// arkadaş ekleme artık yaşa bağlı değil, askıya bağlı ([SanctionStatus]).
@immutable
class AgeStatus {
  const AgeStatus({required this.birthYearSet, required this.isMinor});

  final bool birthYearSet;
  final bool isMinor;

  /// Sunucudan okunamadığında kullanılan kapalı taraf: yıl yazılmamış sayılır,
  /// yani karşılama akışı kullanıcıyı yaş adımında tutar.
  static const AgeStatus unknown = AgeStatus(birthYearSet: false, isMinor: true);

  factory AgeStatus.fromRow(Map<String, dynamic> row) {
    return AgeStatus(
      birthYearSet: row['birth_year_set'] == true,
      isMinor: row['is_minor'] == true,
    );
  }
}

/// Günlük durum ve yaş kapısı okumaları.
class DailyStateRepository {
  DailyStateRepository._();
  static final DailyStateRepository instance = DailyStateRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  /// HUD verisi. Hata durumunda `null` döner — çağıran eldeki değeri korur,
  /// sıfırlanmış bir HUD göstermez.
  Future<DailyState?> read() async {
    try {
      final List<Map<String, dynamic>> rows =
          await _client.from('my_daily_state').select().limit(1);
      if (rows.isEmpty) return null;
      return DailyState.fromRow(rows.first);
    } catch (e) {
      debugPrint('günlük durum okunamadı: $e');
      return null;
    }
  }

  // hasAiCredit() SİLİNDİ (Task 06): sıfır çağrısı vardı. İstemcide kapı
  // YOK ve olmayacak — sınırı sunucu uyguluyor, `analyze-question` OpenAI'ya
  // gitmeden önce. İstemcinin önden dallanması, kotanın iki yerde yaşadığı
  // yanılsamasını üretirdi.

  Future<AgeStatus?> ageStatus() async {
    try {
      final dynamic res = await _client.rpc<dynamic>('my_age_status');
      if (res is List && res.isNotEmpty) {
        return AgeStatus.fromRow((res.first as Map).cast<String, dynamic>());
      }
      if (res is Map) {
        return AgeStatus.fromRow(res.cast<String, dynamic>());
      }
      return null;
    } catch (e) {
      debugPrint('yaş durumu okunamadı: $e');
      return null;
    }
  }

  /// Doğum yılını yazar. TEK YAZIMLIK — ikinci çağrı sunucuda reddedilir.
  ///
  /// Hata YUTULMUYOR: yaş kapısı yasal bir adım, sessizce geçilmemeli.
  /// 13 yaşından küçük bir yıl [tooYoungCode] ile reddedilir; çağıran o dalı
  /// "geçersiz yıl"dan ayırıp nazik bir açıklama gösterir.
  Future<void> setBirthYear(int year) async {
    await _client.rpc<void>(
      'set_birth_year',
      params: <String, dynamic>{'p_year': year},
    );
  }

  /// `set_birth_year`in 13 yaş sınırı için kullandığı özel SQLSTATE (göç 0063).
  static const String tooYoungCode = 'KM013';

  /// Kullanım Koşulları + Gizlilik Politikası onayını deftere yazar ve
  /// damgalanan METİN SÜRÜMÜNÜ döndürür.
  ///
  /// Hata YUTULMUYOR: onay yazılamadıysa kayıt tamamlanmamalı.
  Future<String?> acceptLegalTerms() async {
    final dynamic res = await _client.rpc<dynamic>('accept_legal_terms');
    return res is String ? res : null;
  }
}

final DailyStateRepository dailyStateRepository = DailyStateRepository.instance;
