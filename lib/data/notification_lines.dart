import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mascot.dart';
import '../services/crash_service.dart';
import '../services/supabase_config.dart';

/// Bildirim senaryoları. Anahtarların yazımı ÜÇ YERDE aynı olmak zorunda:
/// buradaki [NotifyKind.payload], sunucudaki `push_kinds.kind` ve
/// `NotificationRouter.handle`'ın switch'i. Ayrışırlarsa bildirim ya hiç
/// gitmez ya da dokunulduğunda yanlış ekrana götürür.
enum NotifyKind {
  /// Seri bugün sürdürülmedi.
  streakRisk,

  /// Bugün planlanmış tekrarlar var, henüz yapılmadı.
  reviewsDue,

  /// Lig haftasının son günü.
  leagueLastDay,

  /// Hafta kapandı, terfi/düşme sonucu.
  ///
  /// **Metinleri var, planlayıcısı yok.** Bildirim zamanlaması Task 03'ün alanı;
  /// buraya bir tetikleyici eklemek o kapsama girer. Metinler taşındı ki
  /// tetikleyici geldiğinde yazılacak bir şey kalmasın.
  leagueResult,

  /// Arkadaş soru gönderdi.
  questionReceived,

  /// Arkadaşlık isteği geldi.
  friendRequest,

  /// Gönderdiğin soruyu arkadaşın çözdü.
  questionSolved,

  /// Uzun süredir uygulamaya girilmedi.
  comeback,

  /// Arkadaşın bir üst lige çıktı.
  friendLeagueUp,

  /// Arkadaşın seri kilometre taşına ulaştı.
  friendStreak;

  /// Bildirime dokunulunca nereye gidileceğini belirleyen anahtar.
  String get payload => switch (this) {
        NotifyKind.streakRisk => 'streak_risk',
        NotifyKind.reviewsDue => 'reviews_due',
        NotifyKind.leagueLastDay => 'league_last_day',
        NotifyKind.leagueResult => 'league_result',
        NotifyKind.questionReceived => 'question_received',
        NotifyKind.friendRequest => 'friend_request',
        NotifyKind.questionSolved => 'question_solved',
        NotifyKind.comeback => 'comeback',
        NotifyKind.friendLeagueUp => 'friend_league_up',
        NotifyKind.friendStreak => 'friend_streak',
      };
}

/// Son gösterileni **dışlayan** satır seçimi.
///
/// Neden var: eskiden iki tarafta da (Dart `Random().nextInt`, SQL
/// `order by random()`) hafıza yoktu. Beş varyantta aynı cümlenin arka arkaya
/// gelme olasılığı %20; aynı iki cümleyi üst üste gören kullanıcı bildirimi
/// okumayı bırakıyor, yani persona sisteminin varlık sebebi ortadan kalkıyor.
///
/// Sözleşme:
/// * `count <= 0` → `-1` (seçilecek satır yok)
/// * `count == 1` → `0` (tekrar kaçınılmaz; bildirimi düşürmekten iyidir)
/// * aksi hâlde `[0, count)` aralığından, `last` HARİÇ, düzgün dağılımla
///
/// Sunucudaki `send_push`'un imleç mantığının birebir aynısı. Saf olduğu için
/// tohumlanmış `Random` ile kare kare test edilebiliyor.
int pickLineIndex(int count, int last, Random rnd) {
  if (count <= 0) return -1;
  if (count == 1) return 0;
  if (last < 0 || last >= count) return rnd.nextInt(count);
  final int r = rnd.nextInt(count - 1);
  return r >= last ? r + 1 : r;
}

/// Bildirim metinlerinin istemci tarafı.
///
/// **Metinler kodda değil veride.** Tek kaynak sunucudaki `push_lines`; bir
/// cümlenin tonunu düzeltmek ya da persona eklemek uygulama güncellemesi
/// gerektirmiyor. Tablo kullanıcıya açık değil (bildirim metni enjeksiyonu
/// yüzeyi olurdu), okuma `notification_lines()` definer fonksiyonundan geçiyor.
///
/// Yerel hatırlatmalar cihazda ve çevrimdışıyken de planlanabildiği için havuz
/// `SharedPreferences`'ta önbelleğe alınıyor.
class NotificationLines {
  NotificationLines._();
  static final NotificationLines instance = NotificationLines._();

  static const String _kCache = 'notify.lines_v1';
  static const String _kLastIdx = 'notify.last_idx.';

  final Random _rnd = Random();

  /// 'kind|mascot' → satırlar, `idx` sırasında.
  Map<String, List<String>> _lines = <String, List<String>>{};

  /// kind → başlık.
  Map<String, String> _titles = <String, String>{};

  bool _loaded = false;

  /// Havuz okunabilir durumda mı (önizleme gösterilip gösterilmeyeceğini
  /// belirlemek için arayüz de soruyor).
  bool get isReady => _lines.isNotEmpty;

  static String _key(NotifyKind kind, Mascot mascot) =>
      '${kind.payload}|${mascot.dbValue}';

  /// Testler için: bellek içi durumu sıfırlar ki [load] diskten yeniden
  /// okusun. Üretimde önbellek süreç ömrü boyunca bir kez okunuyor.
  @visibleForTesting
  void resetForTest() {
    _loaded = false;
    _lines = <String, List<String>>{};
    _titles = <String, String>{};
  }

  /// Önbelleği diskten okur. Ucuz ve tekrar çağrılabilir.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_kCache);
    if (raw == null || raw.isEmpty) return;
    try {
      _apply(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, st) {
      // Bozuk önbellek okunamıyorsa yedek metinlere düşülür ve bir sonraki
      // [refresh] tabloyu yeniden yazar. (Yalnız telemetri.)
      unawaited(reportError(e, st, context: 'notify.linesCacheRead'));
    }
  }

  /// Sunucudan tazeler. Uygulama açılışında ve persona değişince çağrılır.
  ///
  /// Başarısızlık kullanıcıya gösterilmez: eski önbellek çalışmaya devam eder,
  /// hiç önbellek yoksa nötr yedek cümleler kullanılır. (Yalnız telemetri.)
  Future<void> refresh() async {
    if (!SupabaseConfig.isConfigured) return;
    final SupabaseClient client = Supabase.instance.client;
    if (client.auth.currentUser == null) return;
    try {
      final List<dynamic> rows =
          await client.rpc<List<dynamic>>('notification_lines');
      final Map<String, dynamic> packed = _pack(rows);
      if ((packed['lines'] as Map<String, dynamic>).isEmpty) return;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCache, jsonEncode(packed));
      _apply(packed);
    } catch (e, st) {
      unawaited(reportError(e, st, context: 'notify.linesRefresh'));
    }
  }

  /// Satırları `idx` sırasına dizip önbellek biçimine çevirir.
  static Map<String, dynamic> _pack(List<dynamic> rows) {
    final Map<String, List<String?>> byKey = <String, List<String?>>{};
    final Map<String, String> titles = <String, String>{};
    for (final dynamic row in rows) {
      if (row is! Map) continue;
      final Object? kind = row['kind'];
      final Object? mascot = row['mascot'];
      // `idx` JSON'dan int gelir, ama sayısal tipin num'a düşmesi sürüme bağlı;
      // ikisini de kabul etmek bir satırlık iş, hata ayıklaması değil.
      final Object? rawIdx = row['idx'];
      final int? idx = rawIdx is int
          ? rawIdx
          : (rawIdx is num ? rawIdx.toInt() : null);
      final Object? line = row['line'];
      if (kind is! String || mascot is! String || idx == null || line is! String) {
        continue;
      }
      final Object? title = row['title'];
      if (title is String) titles[kind] = title;
      final List<String?> slot =
          byKey.putIfAbsent('$kind|$mascot', () => <String?>[]);
      // `idx` boşluklu gelirse (bir satır silinmişse) araya null konur ve
      // aşağıda ayıklanır; sıra bozulmasın diye indeks doğrudan kullanılıyor.
      while (slot.length <= idx) {
        slot.add(null);
      }
      slot[idx] = line;
    }
    return <String, dynamic>{
      'lines': byKey.map((String k, List<String?> v) =>
          MapEntry<String, dynamic>(k, v.whereType<String>().toList())),
      'titles': titles,
    };
  }

  void _apply(Map<String, dynamic> packed) {
    final Object? lines = packed['lines'];
    final Object? titles = packed['titles'];
    if (lines is Map) {
      _lines = lines.map((Object? k, Object? v) => MapEntry<String, List<String>>(
            k! as String,
            (v! as List<dynamic>).whereType<String>().toList(),
          ));
    }
    if (titles is Map) {
      _titles = titles.map((Object? k, Object? v) =>
          MapEntry<String, String>(k! as String, v! as String));
    }
  }

  /// Senaryonun başlığı. Personaya göre değişmez.
  String title(NotifyKind kind) =>
      _titles[kind.payload] ?? _fallbackTitle(kind);

  /// Senaryo ve persona için bir cümle; yer tutucular doldurulur.
  ///
  /// Havuz boşsa nötr yedeğe düşer — **bildirimi düşürmez.** Yedek cümle içerik
  /// değil emniyet kemeri: yalnızca hiç önbellek oluşmamışken (yeni kurulum +
  /// çevrimdışı) görünür ve personayı duyurmaz.
  Future<String> pick(
    NotifyKind kind,
    Mascot mascot, {
    int? n,
    String? ad,
    int? sira,
    String? lig,
  }) async {
    await load();
    final List<String> lines = _lines[_key(kind, mascot)] ?? const <String>[];
    String text;
    if (lines.isEmpty) {
      text = _fallbackLine(kind);
    } else {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String cursorKey = '$_kLastIdx${kind.payload}';
      final int last = prefs.getInt(cursorKey) ?? -1;
      final int idx = pickLineIndex(lines.length, last, _rnd);
      await prefs.setInt(cursorKey, idx);
      text = lines[idx];
    }
    return fill(text, n: n, ad: ad, sira: sira, lig: lig);
  }

  /// Önizleme için: belirli bir satırı seçer, imleci OYNATMAZ. Persona seçim
  /// ekranı bunu kullanıyor — önizleme göstermek gerçek bildirim sırasını
  /// bozmamalı.
  String? preview(NotifyKind kind, Mascot mascot, int idx) {
    final List<String> lines = _lines[_key(kind, mascot)] ?? const <String>[];
    if (idx < 0 || idx >= lines.length) return null;
    return lines[idx];
  }

  /// Yer tutucuları doldurur. Verilmeyen yer tutucu metinde ham kalmasın diye
  /// sonda genel bir temizlik yok: her senaryo hangi değeri kullandığını bilir
  /// ve `notification_service` hepsini veriyor.
  static String fill(
    String text, {
    int? n,
    String? ad,
    int? sira,
    String? lig,
  }) {
    String s = text;
    if (n != null) s = s.replaceAll('{n}', '$n');
    if (ad != null) s = s.replaceAll('{ad}', ad);
    if (sira != null) s = s.replaceAll('{sira}', '$sira');
    if (lig != null) s = s.replaceAll('{lig}', lig);
    return s;
  }

  /// Önbellek hiç oluşmamışsa kullanılan başlık.
  static String _fallbackTitle(NotifyKind kind) => switch (kind) {
        NotifyKind.reviewsDue => 'Tekrar zamanı',
        NotifyKind.streakRisk => 'Serini sürdür',
        NotifyKind.comeback => 'Seni özledik',
        NotifyKind.leagueLastDay => 'Lig haftası bitiyor',
        NotifyKind.leagueResult => 'Hafta kapandı',
        NotifyKind.questionReceived => 'Sana soru geldi',
        NotifyKind.friendRequest => 'Arkadaşlık isteği',
        NotifyKind.questionSolved => 'Soru çözüldü',
        NotifyKind.friendLeagueUp => 'Arkadaşın yükseldi',
        NotifyKind.friendStreak => 'Arkadaşın seri yapıyor',
      };

  /// Önbellek hiç oluşmamışsa kullanılan nötr gövde. **İçerik değil**: personayı
  /// duyurmaz, yalnızca bildirimin hiç gitmemesini engeller. Ton düzeltmesi
  /// buraya değil tabloya yapılır.
  static String _fallbackLine(NotifyKind kind) => switch (kind) {
        NotifyKind.reviewsDue => 'Bugün {n} tekrar seni bekliyor.',
        NotifyKind.streakRisk => '{n} günlük serin sürüyor. Bir soru yeter.',
        NotifyKind.comeback => 'Kaldığın yerden devam edebilirsin.',
        NotifyKind.leagueLastDay => 'Lig haftası bugün kapanıyor. Sıran {sira}.',
        NotifyKind.leagueResult => 'Hafta kapandı: {lig}.',
        NotifyKind.questionReceived => '{ad} sana bir soru gönderdi.',
        NotifyKind.friendRequest => '{ad} arkadaşlık isteği gönderdi.',
        NotifyKind.questionSolved => '{ad} gönderdiğin soruyu çözdü.',
        NotifyKind.friendLeagueUp => '{ad} bir üst lige çıktı: {lig}.',
        NotifyKind.friendStreak => '{ad} {n} günlük seriye ulaştı.',
      };
}

final NotificationLines notificationLines = NotificationLines.instance;
