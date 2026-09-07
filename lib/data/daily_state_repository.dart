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

  /// Boş/çevrimdışı durum. Can dolu varsayılıyor: kullanıcıyı sunucuya
  /// sormadan "hakkın bitti" diye kısıtlamak, çevrimdışında yanlış olurdu —
  /// gerçek sınırı zaten sunucu uyguluyor.
  static const DailyState unknown = DailyState(
    aiLeft: 5,
    aiQuota: 5,
    aiResetsAt: null,
    gems: 0,
    xp: 0,
    streak: 0,
    weeklyXp: 0,
    league: League.bronz,
  );

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

/// Yaş kapısı ve veli onayının durumu.
///
/// Yaşın KENDİSİNİ taşımıyor: arayüzün ihtiyacı olan tek şey kapının açık olup
/// olmadığı ve onayın hangi adrese gittiği.
@immutable
class GuardianStatus {
  const GuardianStatus({
    required this.isMinor,
    required this.birthYearSet,
    required this.consentGranted,
    required this.canAddFriends,
    this.guardianEmail,
  });

  final bool isMinor;
  final bool birthYearSet;
  final bool consentGranted;
  final bool canAddFriends;
  final String? guardianEmail;

  /// Onay istendi ama henüz gelmedi.
  bool get waitingForGuardian =>
      isMinor && guardianEmail != null && !consentGranted;

  static const GuardianStatus unknown = GuardianStatus(
    isMinor: true,
    birthYearSet: false,
    consentGranted: false,
    canAddFriends: false,
  );

  factory GuardianStatus.fromRow(Map<String, dynamic> row) {
    return GuardianStatus(
      isMinor: row['is_minor'] == true,
      birthYearSet: row['birth_year_set'] == true,
      consentGranted: row['consent_granted'] == true,
      canAddFriends: row['can_add_friends'] == true,
      guardianEmail: row['guardian_email'] as String?,
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

  /// Bir yapay zekâ okutma hakkı harcar.
  ///
  /// Hak yoksa HATA ATMAZ: `allowed = false` döner ve çağıran elle giriş
  /// yolunu açar. Kaydetme yolu asla kapanmıyor.
  ///
  /// NOT: gerçek tüketim `analyze-question` edge fonksiyonunda, OpenAI'ya
  /// gitmeden önce yapılıyor. Bu metot yalnızca istemcinin akışı önceden
  /// dallandırması için var; sınırı uygulayan o değil, sunucu.
  Future<bool> hasAiCredit() async {
    final DailyState? s = await read();
    return s?.hasAi ?? true;
  }

  Future<GuardianStatus?> guardianStatus() async {
    try {
      final dynamic res = await _client.rpc<dynamic>('my_guardian_status');
      if (res is List && res.isNotEmpty) {
        return GuardianStatus.fromRow((res.first as Map).cast<String, dynamic>());
      }
      if (res is Map) {
        return GuardianStatus.fromRow(res.cast<String, dynamic>());
      }
      return null;
    } catch (e) {
      debugPrint('veli onayı durumu okunamadı: $e');
      return null;
    }
  }

  /// Doğum yılını yazar. TEK YAZIMLIK — ikinci çağrı sunucuda reddedilir.
  ///
  /// Hata YUTULMUYOR: yaş kapısı yasal bir adım, sessizce geçilmemeli.
  Future<void> setBirthYear(int year) async {
    await _client.rpc<void>(
      'set_birth_year',
      params: <String, dynamic>{'p_year': year},
    );
  }

  /// Veli onayı bağlantısını gönderir. Hata yukarı verilir.
  Future<void> requestGuardianConsent(String email) async {
    await _client.rpc<void>(
      'request_guardian_consent',
      params: <String, dynamic>{'p_email': email},
    );
  }
}

final DailyStateRepository dailyStateRepository = DailyStateRepository.instance;
