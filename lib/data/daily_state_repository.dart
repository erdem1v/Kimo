import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_credit.dart';
import '../models/social.dart';
import '../state/features.dart';

/// Kullanıcının günlük durumu — HUD'un ve hak duvarının tek kaynağı.
///
/// ANALİZ HAKKININ HİÇBİR DEĞERİ İSTEMCİDE HESAPLANMIYOR. Durum (`aiState`),
/// kalan sayı, sonraki hakkın saati, ayın yenilenme günü ve reklam yolunun
/// görünüp görünmeyeceği hepsi sunucudan tek sorguda geliyor
/// (`public.my_daily_state` → `public.ai_state()`, göç 0075). Kayan pencere,
/// aylık cap ve katman mantığı orada; burada yalnızca gösterim var.
///
/// İKİ AYRI `null` VAR VE İKİSİ DE "HİÇBİR ŞEY GÖSTER" DEMEK:
///   * `DailyState == null`  → görünüm okunamadı (ağ, oturum, izin).
///   * `aiState == null`     → satır geldi ama durum tanınmadı/eksik.
/// Hiçbiri "sıfır hak" değil. Sıfır göstermek gerçekten sıfır olmasıyla
/// ayırt edilemezdi — eski `?? 5` / `?? 0` yedeklerinin ürettiği hata tam
/// buydu ve o yüzden bu sınıfta uydurma varsayılan YOK.
@immutable
class DailyState {
  const DailyState({
    required this.aiState,
    required this.aiLeft,
    required this.aiTier,
    required this.gems,
    required this.xp,
    required this.streak,
    required this.weeklyXp,
    required this.league,
    this.aiWindowLeft = 0,
    this.aiWindowLimit = 0,
    this.aiMonthLeft = 0,
    this.aiMonthLimit = 0,
    this.aiWindowHours = 0,
    this.aiNextAtHm,
    this.aiMonthResetsOn,
    this.adRewardsLeft,
    this.adRewardsPerDay = 0,
    this.adOffer = false,
    this.plusWindowLimit = 0,
    this.plusMonthLimit = 0,
    this.freeWindowLimit = 0,
    this.freeMonthLimit = 0,
    this.dailyGoalDate,
    this.quietStart,
    this.quietEnd,
    this.premiumUntil,
    this.lastActivityDate,
    this.serverToday,
    this.weekStart,
    this.reviewedTodayCount = 0,
    this.dueCount = 0,
    this.unsolvedReceivedCount = 0,
    this.ffPairStreak,
    this.ffMultiCapture,
    this.ffAdReward,
    this.ffIap,
    this.subStatus,
    this.subStore,
    this.subExpiresAt,
    this.subRenews = false,
    this.subInTrial = false,
  });

  /// Hakkın durumu. `null` = sunucunun söylediği değer tanınmadı → arayüz
  /// hiçbir şey çizmiyor.
  final AiState? aiState;

  /// BAĞLAYICI kalan hak: pencere ile ay kalanının küçüğü (anonimde ömür
  /// kalanı). Hangi sınırın bağladığını sunucu hesaplıyor. `null` = okunamadı.
  final int? aiLeft;

  /// Katman. Duvarın anonim dalı ve Plus satırının çizilip çizilmeyeceği buna
  /// bağlı.
  final AiTier? aiTier;

  /// Kayan penceredeki kalan ve o katmanın taban pencere sınırı.
  final int aiWindowLeft;
  final int aiWindowLimit;

  /// Aylık cap'te kalan ve cap'in kendisi.
  final int aiMonthLeft;
  final int aiMonthLimit;

  /// Pencerenin saat cinsinden uzunluğu — "8 saatte 10 soru" metni için.
  final int aiWindowHours;

  /// Sonraki hakkın Istanbul duvar saati, `HH:MM` biçiminde ve SUNUCUDAN
  /// hazır geliyor.
  ///
  /// Neden istemci üretmiyor: cihaz saatini değiştiren bir öğrenciye yanlış
  /// saat gösterilmesin. Deponun `today`/`week_start` kararının aynısı.
  /// Aylık cap dolduğunda sunucu bunu `null` yapıyor — o saat artık bir şey
  /// vaat etmiyor.
  ///
  /// GERİ SAYIM GÖSTERİLMİYOR, yalnızca saat (tasarım kararı, değişmedi).
  final String? aiNextAtHm;

  /// Ayın yenilendiği Istanbul takvim günü. Ay ADI istemcide konuyor
  /// (`trLocativeMonthDay`): Postgres'in `TM` ay adları `lc_time`'a bağlı ve
  /// Supabase'de `tr_TR` olduğu varsayılamaz.
  final DateTime? aiMonthResetsOn;

  /// Bugün kalan ödüllü reklam hakkı. `null` = okunamadı.
  final int? adRewardsLeft;

  /// Günlük reklam tavanı — "Yarın 3 reklam hakkın yeniden açılır" için.
  final int adRewardsPerDay;

  /// Reklam yolu SUNULUYOR mu. Kararı sunucu veriyor: katman ücretsiz,
  /// askı yok, günlük tavan dolmamış, aylık cap dolmamış ve pencere dolmuş.
  /// İstemci bu koşulları yeniden türetmiyor.
  final bool adOffer;

  /// Kıyas tablosundaki Plus rakamları — sunucudan, koda gömülü değil.
  final int plusWindowLimit;
  final int plusMonthLimit;

  /// ÜCRETSİZ katmanın sınırları — çağıranın katmanından BAĞIMSIZ (0099).
  ///
  /// [aiWindowLimit] / [aiMonthLimit] kullanıcının KENDİ katmanını anlatıyor;
  /// paywall'ın "Ücretsiz" sütunu ise ücretsiz katmanı anlatmak zorunda.
  /// Sunucu ayrı alan yayınlamadığı sürece ekran `ai_*`i kullanıyordu ve
  /// abonede tablo "Ücretsiz 50 | Plus 50", anonimde "Ücretsiz 3" yazıyordu.
  final int freeWindowLimit;
  final int freeMonthLimit;

  /// Günlük hedef ödülünün alındığı gün (Istanbul). `null` = bugün alınmadı.
  ///
  /// Sunucuda hep duruyordu ama yayınlanmıyordu (0099). İstemci yalnızca
  /// oturum-içi bir alana bakıyordu ve çıkışta sıfırlıyordu: yeniden
  /// kurulumda ya da ikinci cihazda ödül "alınmadı" sanılıyor,
  /// `claim_daily_goal` sessizce sıfır ödül döndürüyordu.
  final DateTime? dailyGoalDate;

  /// Sessiz saat aralığı — SUNUCUNUN kopyası (0100).
  ///
  /// Yazma `set_quiet_hours`tan geçiyor; burası okuma yolu. Yalnızca cihazda
  /// tutulsaydı ikinci cihaz kendi varsayılanını gösterir, sunucu ise ilk
  /// cihazın yazdığını uygulardı.
  final int? quietStart;
  final int? quietEnd;

  /// Günlük hedef ödülü BUGÜN alınmış mı (sunucunun günü ile).
  bool get dailyGoalClaimed =>
      dailyGoalDate != null &&
      serverToday != null &&
      !dailyGoalDate!.isBefore(serverToday!);

  /// Premium aboneliğin bitişi (varsa). Task 13'ten beri DOLU: tek yazar
  /// `apply_subscription` (göç 0092), defterden türetiliyor.
  final DateTime? premiumUntil;

  // ------------------------------------------------------------- abonelik
  //
  // Tek bir `premiumUntil` "deneme mi, yenilenecek mi, hangi mağaza" sorularına
  // cevap veremiyor ve eksik veriyle karar UYDURMAK bu sınıfın yasakladığı şey.
  // Sunucu ayrı bir fonksiyondan (`subscription_state`) veriyor.
  //
  // `null` = ABONELİK YOK ya da sütun okunamadı. İkisi de aynı şeyi
  // gerektiriyor (satın alma yüzeyini normal göster), bu yüzden ayrılmıyor.

  /// `trial | active | grace | expired | refunded | revoked`.
  final String? subStatus;

  /// `ios | android` — "Aboneliği yönet" bağlantısı hangi mağazaya gidecek.
  final String? subStore;

  /// Dönem bitişi. `premiumUntil` ile aynı olmak zorunda değil: iki
  /// platformdan abone olan birinde `premiumUntil` en geç olanı taşır.
  final DateTime? subExpiresAt;

  /// Dönem sonunda kendiliğinden yenilenecek mi (iptal edilmediyse true).
  final bool subRenews;

  /// Ücretsiz deneme süresi içinde mi.
  final bool subInTrial;

  /// Etkin bir aboneliği var mı — paywall'ın "zaten Plus'sın" dalı.
  bool get hasSubscription =>
      subStatus == 'trial' || subStatus == 'active' || subStatus == 'grace';

  final int gems;
  final int xp;

  /// ETKİN seri — sunucu kapıladı (Task 03): kopmuş seri 0 gelir.
  final int streak;
  final int weeklyXp;
  final League league;

  /// Sunucudaki son aktivite günü.
  final DateTime? lastActivityDate;

  /// Sunucunun (Europe/Istanbul) bugünü. Günün tek tanımı bu.
  final DateTime? serverToday;

  /// Sunucunun ISO hafta başı. Duvar sayacının hafta anahtarı bu — cihaz
  /// saatinden hafta üretmek saatini ileri alan kullanıcıya sayacı
  /// sıfırlatırdı.
  final DateTime? weekStart;

  /// Istanbul gününe göre bugün cevaplanmış tekrar sayısı.
  final int reviewedTodayCount;

  /// Vadesi gelmiş tekrar sayısı.
  final int dueCount;

  /// Arkadaşlardan gelen, çözülmemiş soru sayısı.
  final int unsolvedReceivedCount;

  // ------------------------------------------------------- özellik bayrakları
  //
  // Sunucudan gelen uzaktan kapatma anahtarları (`app_config` → `feature_flags()`
  // → `my_daily_state`, göç 0079). Riskli bir yüzey ölçüm kötü çıkarsa MAĞAZA
  // GÜNCELLEMESİ BEKLENMEDEN kapatılabilsin diye var.
  //
  // `null` = SÜTUN OKUNAMADI, "kapalı" DEĞİL. Bu sınıfın değişmezi burada da
  // geçerli: uydurma varsayılan yok. `null` durumunda karar derleme zamanındaki
  // [Features] sabitine düşüyor — aşağıdaki üç getter tek karar noktası.
  final bool? ffPairStreak;
  final bool? ffMultiCapture;
  final bool? ffAdReward;
  final bool? ffIap;

  /// Ortak seri yüzeyi çizilsin mi.
  bool get pairStreakEnabled => ffPairStreak ?? Features.pairStreakFallback;

  /// Çoklu çekim modu (premium kapısından BAĞIMSIZ: bu bayrak özelliğin
  /// tamamını kapatıyor, ücretsiz/premium ayrımını yapmıyor).
  bool get multiCaptureEnabled =>
      ffMultiCapture ?? Features.multiCaptureFallback;

  /// Ödüllü reklam yüzeyi. Sunucu ayrıca `ad_offer` ile "şu an teklif edilir
  /// mi" diyor; bu bayrak ondan ÖNCE gelen bir kill switch.
  bool get adRewardEnabled => ffAdReward ?? Features.adRewardFallback;

  /// Satın alma yüzeyi. Mağaza tarafı arızalanır ya da fiyat sorgusu boş
  /// dönerse paywall'ın düğmesi SÜRÜM BEKLEMEDEN kapanabilmeli.
  bool get iapEnabled => ffIap ?? Features.iapFallback;

  /// Sunucuya göre bugün aktif miyim (seri bugün işlendi mi).
  bool get activeToday =>
      lastActivityDate != null &&
      serverToday != null &&
      !lastActivityDate!.isBefore(serverToday!);

  /// Gösterge çizilebilir mi: durum VE sayı birlikte okunabildi mi.
  bool get creditReadable => aiState != null && aiLeft != null;

  /// Seviye XP'den TÜRETİLİR; sunucuda ayrı bir sütun yok.
  ///
  /// Her 1000 XP bir seviye. Tasarımdaki "Seviye 7 · 860/1000" göstergesi bu
  /// formülün karşılığı.
  int get level => xp ~/ xpPerLevel + 1;

  /// Bu seviyede kazanılmış XP (0–999).
  int get levelProgress => xp % xpPerLevel;

  static const int xpPerLevel = 1000;

  static int? _int(Object? v) => (v as num?)?.toInt();

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  /// ÜÇ DURUMLU bayrak okuyucu: `true`, `false` ya da **okunamadı**.
  ///
  /// `v == true` yazmak yeterli DEĞİL — o, eksik sütunu ve `null`'ı "kapalı"ya
  /// çevirir ve bu sınıfın yasakladığı uydurma varsayılanın ta kendisidir.
  /// Sunucu bayrağı taşımıyorsa karar derleme zamanındaki [Features] sabitine
  /// düşmeli, sessizce "kapalı"ya değil.
  static bool? _flag(Object? v) => v is bool ? v : null;

  factory DailyState.fromRow(Map<String, dynamic> row) {
    return DailyState(
      // UYDURMA VARSAYILAN YOK: sütun yoksa ya da tanınmıyorsa `null` kalıyor
      // ve arayüz hiçbir şey çizmiyor.
      aiState: AiState.fromDb(row['ai_state'] as String?),
      aiLeft: _int(row['ai_left']),
      aiTier: AiTier.fromDb(row['ai_tier'] as String?),
      aiWindowLeft: _int(row['ai_window_left']) ?? 0,
      aiWindowLimit: _int(row['ai_window_limit']) ?? 0,
      aiMonthLeft: _int(row['ai_month_left']) ?? 0,
      aiMonthLimit: _int(row['ai_month_limit']) ?? 0,
      aiWindowHours: _int(row['ai_window_hours']) ?? 0,
      aiNextAtHm: row['ai_next_at_hm'] as String?,
      aiMonthResetsOn: _date(row['ai_month_resets_on']),
      adRewardsLeft: _int(row['ad_rewards_left']),
      adRewardsPerDay: _int(row['ad_rewards_per_day']) ?? 0,
      adOffer: row['ad_offer'] == true,
      plusWindowLimit: _int(row['plus_window_limit']) ?? 0,
      plusMonthLimit: _int(row['plus_month_limit']) ?? 0,
      freeWindowLimit: _int(row['free_window_limit']) ?? 0,
      freeMonthLimit: _int(row['free_month_limit']) ?? 0,
      dailyGoalDate: _date(row['daily_goal_date']),
      quietStart: _int(row['quiet_start']),
      quietEnd: _int(row['quiet_end']),
      premiumUntil: _date(row['premium_until']),
      gems: _int(row['gems']) ?? 0,
      xp: _int(row['xp']) ?? 0,
      streak: _int(row['streak']) ?? 0,
      weeklyXp: _int(row['weekly_xp']) ?? 0,
      league: League.fromDb(row['league'] as String?),
      lastActivityDate: _date(row['last_activity_date']),
      serverToday: _date(row['today']),
      weekStart: _date(row['week_start']),
      reviewedTodayCount: _int(row['reviewed_today_count']) ?? 0,
      dueCount: _int(row['due_count']) ?? 0,
      unsolvedReceivedCount: _int(row['unsolved_received_count']) ?? 0,
      ffPairStreak: _flag(row['ff_pair_streak']),
      ffMultiCapture: _flag(row['ff_multi_capture']),
      ffAdReward: _flag(row['ff_ad_reward']),
      ffIap: _flag(row['ff_iap']),
      subStatus: row['sub_status'] as String?,
      subStore: row['sub_store'] as String?,
      subExpiresAt: _date(row['sub_expires_at']),
      // `?? false`: abonelik YOKSA sunucu satır döndürmüyor ve bu alanlar
      // null geliyor. "Yenilenmeyecek" ve "denemede değil" doğru okuma.
      subRenews: _flag(row['sub_renews']) ?? false,
      subInTrial: _flag(row['sub_in_trial']) ?? false,
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
  const AgeStatus({
    required this.birthYearSet,
    required this.isMinor,
    this.birthYear,
  });

  final bool birthYearSet;
  final bool isMinor;

  /// Kayıtlı doğum yılı (0097). Ayarlar satırı bunu gösteriyor: değer
  /// DEĞİŞTİRİLEMEZ olduğu için kullanıcının en azından görebilmesi gerek
  /// (Task 14 · K2). Yıl yazılmamışsa null.
  final int? birthYear;

  /// Sunucudan okunamadığında kullanılan kapalı taraf: yıl yazılmamış sayılır,
  /// yani karşılama akışı kullanıcıyı yaş adımında tutar.
  static const AgeStatus unknown = AgeStatus(birthYearSet: false, isMinor: true);

  factory AgeStatus.fromRow(Map<String, dynamic> row) {
    return AgeStatus(
      birthYearSet: row['birth_year_set'] == true,
      isMinor: row['is_minor'] == true,
      // ESKİ SUNUCU SÜRÜMÜNE DAYANIKLI: alan yoksa null kalıyor ve satır
      // eski hâlindeki notu göstermeye devam ediyor.
      birthYear: (row['birth_year'] as num?)?.toInt(),
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
  //
  // `hasAi` getter'ı da SİLİNDİ (Task 10): tek çağıranı `today_screen`in
  // açıklama sayfasıydı ve artık sayıya değil `aiState`e dallanıyor. Bir
  // sayıya bakıp "hak var mı" diye karar vermek, durumun tek kaynağının
  // sunucu olduğu kuralını yeniden deliyordu.

  /// Ödüllü reklam için sunucudan bir nonce alır (AdMob `customData`).
  ///
  /// Dönüş `null` ise reklam yolu AÇILMIYOR — ve bu bir hata değil: sunucu
  /// "işe yaramaz" demiş olabilir (ay dolu, premium, anonim, zaten hak var,
  /// günlük tavan dolu). Çağıran sessizce vazgeçiyor, kullanıcıya hata
  /// göstermiyor.
  ///
  /// ÖDÜL BU ÇAĞRIYLA VERİLMİYOR. Nonce yalnızca AdMob'a gidecek bir
  /// belirteç; hakkı Google'ın imzalı sunucu geri çağrısı veriyor
  /// (`supabase/functions/ad-reward`). İstemci "izledim" diyemiyor.
  Future<String?> startAdReward() async {
    try {
      final dynamic res = await _client.rpc<dynamic>('start_ad_reward');
      final Map<String, dynamic>? row = switch (res) {
        final List<dynamic> l when l.isNotEmpty =>
          (l.first as Map<dynamic, dynamic>).cast<String, dynamic>(),
        final Map<dynamic, dynamic> m => m.cast<String, dynamic>(),
        _ => null,
      };
      if (row == null || row['ok'] != true) {
        debugPrint('reklam ödülü başlatılmadı: ${row?['reason']}');
        return null;
      }
      final String? nonce = row['ad_nonce'] as String?;
      return (nonce == null || nonce.isEmpty) ? null : nonce;
    } catch (e) {
      debugPrint('reklam ödülü başlatılamadı: $e');
      return null;
    }
  }

  /// Sessiz saat aralığını sunucuya yazar (0100).
  ///
  /// Sütunlar kilitli; tek yazma yolu bu RPC. Yerel kopya gösterim ve cihaz
  /// hatırlatmaları için, UYGULAYAN taraf `send_push`.
  Future<void> setQuietHours(int start, int end) async {
    await Supabase.instance.client.rpc<void>(
      'set_quiet_hours',
      params: <String, dynamic>{'p_start': start, 'p_end': end},
    );
  }

  /// Onboarding testinin dikişi (Task 18): akış yaş durumunu ilk karede
  /// okuyor ve test ortamında `Supabase.instance` yok.
  @visibleForTesting
  static Future<AgeStatus?> Function()? ageStatusOverride;

  Future<AgeStatus?> ageStatus() async {
    final Future<AgeStatus?> Function()? seam = ageStatusOverride;
    if (seam != null) return seam();
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
