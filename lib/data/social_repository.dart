import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mascot.dart';
import '../services/crash_service.dart';
import '../models/social.dart';

/// Sosyal katman: herkese açık profiller (arama/liderlik) ve karşılıklı
/// onaylı arkadaşlık istekleri.
///
/// Okuma `profiles_public` görünümünden yapılır (yalnızca güvenli kolonlar:
/// id, nickname, mascot, xp, streak). Yazma kendi `profiles` satırına.
class SocialRepository {
  SocialRepository._();
  static final SocialRepository instance = SocialRepository._();

  /// Arama/liderlik için okunan görünüm.
  static const String _publicView = 'profiles_public';

  SupabaseClient get _client => Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  /// Oturumdaki kullanıcının kimliği (listelerde "sen" ayrımı için).
  String? get currentUserId => _uid;

  /// Kendi profil satırını oluşturur/günceller. Oturum açıldığında çağrılır.
  ///
  /// Doğrudan `upsert` yerine RPC: takma ad sunucuda doğrulanıyor (uzunluk,
  /// kontrol karakteri, sistem hesabı kimliğinin taklidi) ve `profiles` üzerinde
  /// istemcinin INSERT/UPDATE yetkisine hiç ihtiyaç kalmıyor.
  Future<void> ensureProfile({
    required String nickname,
    Mascot? mascot,
  }) async {
    if (_uid == null) return;
    await _client.rpc<void>(
      'upsert_my_profile',
      params: <String, dynamic>{
        'p_nickname': nickname,
        'p_mascot': mascot?.dbValue,
      },
    );
  }

  // NOT: `syncStats` KALDIRILDI. XP / seri / haftalık XP artık istemciden
  // yazılmıyor — tek bir PATCH isteği lig ve skor tablosunu sahteleyebiliyordu.
  // Değerler `submit_pool_answer` / `submit_sent_answer` / `submit_review` /
  // `claim_daily_goal` RPC'lerinin yanıtından geliyor ve
  // `GameProgress.applyServerTotals` ile uygulanıyor.

  /// Kendi oyunlaştırma verilerim (seri için son aktif gün dahil). Yalnızca
  /// kendi satırım okunur; profiles'ın RLS'i buna izin verir.
  Future<Map<String, dynamic>?> myStats() async {
    final String? uid = _uid;
    if (uid == null) return null;
    try {
      return await _client
          .from('profiles')
          .select(
            'xp, streak, weekly_xp, week_start, last_activity_date, league',
          )
          .eq('id', uid)
          .maybeSingle();
    } catch (e, st) {
      // Çağıran null'u "veri yok" sayıp yerel değerlerle sürer; iz bırak.
      unawaited(reportError(e, st, context: 'social.myStats'));
      return null;
    }
  }

  /// Bu haftaki lig grubum: 15 kişilik gruba yerleştirir (gerekirse yenisini
  /// açar), geçmiş haftaları sonuçlandırır ve sıralamayı döndürür.
  Future<LeagueBoard?> myLeagueBoard() async {
    try {
      await _client.rpc<dynamic>('ensure_league_membership');
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'my_league_board',
      );
      if (rows.isEmpty) return null;
      final Map<String, dynamic> first = (rows.first as Map)
          .cast<String, dynamic>();
      return LeagueBoard(
        tier: League.fromDb(first['tier'] as String?),
        weekStart:
            DateTime.tryParse(first['week_start'] as String? ?? '') ??
            weekStart(DateTime.now()),
        entries: rows
            .map(
              (dynamic r) =>
                  LeagueEntry.fromRow((r as Map).cast<String, dynamic>()),
            )
            .toList(),
      );
    } catch (e, st) {
      unawaited(reportError(e, st, context: 'social.myLeagueBoard'));
      return null;
    }
  }

  /// Kendi profilim (yoksa null).
  Future<PublicProfile?> myProfile() async {
    final String? uid = _uid;
    if (uid == null) return null;
    final Map<String, dynamic>? row = await _client
        .from(_publicView)
        .select()
        .eq('id', uid)
        .maybeSingle();
    return row == null ? null : PublicProfile.fromRow(row);
  }

  // TAKMA AD ARAMASI KALDIRILDI (Task 02, Dalga 5).
  //
  // `search()` burada `profiles_public` üzerinde `ilike '%q%'` yapıyordu ve
  // `xp`'ye göre sıralı ilk 20'yi döndürüyordu. İki sonucu vardı: (1) yaygın
  // bir harf dizisiyle ("ar", "el") bütün kullanıcı tabanı sayfa sayfa
  // dökülebiliyordu, (2) `xp` sıralaması en aktif kullanıcıları listenin
  // başına koyuyordu — yani hedef seçmeyi kolaylaştırıyordu.
  //
  // Task 01 bunu "dizin dökülebilirliği, sosyal/UX pass'ine ertelendi" diye
  // açık bırakmıştı. Yerini arkadaş kodu aldı: 31 harflik alfabeden 6 karakter
  // (≈887 milyon) ve `add_friend_by_code` saatte 20 denemeyle sınırlı.
  //
  // Görünüm DURUYOR: kimliğe göre tekil/çoklu okuma (arkadaş listesi, lig
  // tahtası) hâlâ gerekiyor. Giden yalnızca serbest metin araması.

  /// Beni ilgilendiren tüm arkadaşlık kayıtları (istek + kabul).
  Future<List<Friendship>> relations() async {
    final String? uid = _uid;
    if (uid == null) return <Friendship>[];
    final List<Map<String, dynamic>> rows = await _client
        .from('friendships')
        .select()
        .or('requester_id.eq.$uid,addressee_id.eq.$uid');
    return rows.map(Friendship.fromRow).toList();
  }

  /// Verilen kimliklerin profillerini getirir.
  Future<List<PublicProfile>> profilesByIds(List<String> ids) async {
    if (ids.isEmpty) return <PublicProfile>[];
    final List<Map<String, dynamic>> rows = await _client
        .from(_publicView)
        .select()
        .inFilter('id', ids)
        .order('xp', ascending: false);
    return rows.map(PublicProfile.fromRow).toList();
  }

  /// Tek bir kullanıcının açık profili (profil kartı ekranı için).
  Future<PublicProfile?> profileById(String id) async {
    try {
      final Map<String, dynamic>? row = await _client
          .from(_publicView)
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : PublicProfile.fromRow(row);
    } catch (e, st) {
      unawaited(reportError(e, st, context: 'social.profileById'));
      return null;
    }
  }

  // ------------------------------------------------------ profil fotoğrafı

  static const String _avatarBucket = 'avatars';

  /// İmzalı URL ömrü. Önbellek bu değerle BİRLİKTE yaşıyor (aşağıya bakın);
  /// ikisini birbirinden bağımsız değiştirmeyin.
  static const int _signedUrlTtlSeconds = 600;

  /// İmzalı URL'ler kısa ömürlü; aynı yolu tekrar tekrar imzalamayalım.
  ///
  /// ÖNEMLİ: önbellek artık SON KULLANMA ZAMANI tutuyor. Eskiden URL'i süresiz
  /// saklıyordu, imza ise 1 saatte ölüyordu — yani bir saati aşan oturumlarda
  /// avatarlar sessizce kırılıyor, kullanıcı maskot simgesine düşüyordu.
  final Map<String, _SignedUrl> _avatarUrls = <String, _SignedUrl>{};

  /// Profil fotoğrafı için gösterilebilir URL (yoksa null).
  Future<String?> avatarUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    final _SignedUrl? cached = _avatarUrls[path];
    if (cached != null && !cached.isStale) return cached.url;
    try {
      final String url = await _client.storage
          .from(_avatarBucket)
          .createSignedUrl(path, _signedUrlTtlSeconds);
      _avatarUrls[path] = _SignedUrl(
        url,
        DateTime.now().add(const Duration(seconds: _signedUrlTtlSeconds)),
      );
      return url;
    } catch (e, st) {
      unawaited(reportError(e, st, context: 'social.avatarSignedUrl'));
      _avatarUrls.remove(path);
      return null;
    }
  }

  /// Görsel yüklenemediğinde çağrılır: bir sonraki istek yeniden imzalasın.
  void invalidateAvatarUrl(String? path) {
    if (path != null) _avatarUrls.remove(path);
  }

  /// Yeni profil fotoğrafı yükler, yolunu profile yazar ve ESKİ DOSYALARI SİLER.
  ///
  /// Hata artık yutulmuyor: [AvatarException] fırlatır, çağıran kullanıcıya
  /// gösterir. Eskiden null dönüyordu; "yüklendi ama görünmüyor" durumunun
  /// sebebi hiçbir yerde görünmüyordu.
  Future<String> uploadAvatar(Uint8List bytes) async {
    final String? uid = _uid;
    if (uid == null) throw const AvatarException('Oturum bulunamadı.');
    final String path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      await _client.storage
          .from(_avatarBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
    } catch (e) {
      throw AvatarException('Fotoğraf yüklenemedi: ${_reason(e)}');
    }
    try {
      await _client
          .from('profiles')
          .update(<String, dynamic>{'avatar_path': path})
          .eq('id', uid);
    } on PostgrestException catch (e) {
      throw AvatarException('Fotoğraf kaydedilemedi: ${e.message}');
    }
    // Yeni avatar yazıldı; eskileri süpür. Bu adım başarısız olursa kullanıcının
    // işlemi yine de başarılı — yalnızca depoda artık dosya kalır.
    await _sweepAvatarFolder(uid, keep: path, strict: false);
    return path;
  }

  /// Profil fotoğrafını kaldırır: sütunu boşaltır VE dosyayı gerçekten siler.
  ///
  /// Eskiden yalnızca `avatar_path` null'lanıyordu, dosya depoda sonsuza dek
  /// kalıyordu. Kullanıcının sildiği veri gerçekten silinmeliydi
  /// (KVKK Md. 7 / GDPR Md. 17).
  Future<void> removeAvatar() async {
    final String? uid = _uid;
    if (uid == null) throw const AvatarException('Oturum bulunamadı.');
    try {
      await _client
          .from('profiles')
          .update(<String, dynamic>{'avatar_path': null})
          .eq('id', uid);
    } on PostgrestException catch (e) {
      throw AvatarException('Fotoğraf kaldırılamadı: ${e.message}');
    }
    // Burada silme BAŞARISIZ OLURSA kullanıcıya söylüyoruz: "sildim" deyip
    // dosyayı bırakmak tam olarak düzeltmeye çalıştığımız davranış.
    await _sweepAvatarFolder(uid, keep: null, strict: true);
  }

  /// Kullanıcının avatar klasöründe [keep] dışındaki her şeyi siler.
  ///
  /// Klasörü tarayarak çalışıyor, "önceki yolu hatırla" mantığıyla değil: her
  /// avatar değişimi yeni bir zaman damgalı nesne yarattığı için geçmişte
  /// birikmiş artıklar da böylece temizleniyor.
  Future<void> _sweepAvatarFolder(
    String uid, {
    required String? keep,
    required bool strict,
  }) async {
    try {
      final List<FileObject> files =
          await _client.storage.from(_avatarBucket).list(path: uid);
      final List<String> stale = <String>[
        for (final FileObject f in files)
          if ('$uid/${f.name}' != keep) '$uid/${f.name}',
      ];
      if (stale.isEmpty) return;
      await _client.storage.from(_avatarBucket).remove(stale);
      for (final String p in stale) {
        _avatarUrls.remove(p);
      }
    } catch (e) {
      if (strict) {
        throw AvatarException('Fotoğraf dosyası silinemedi: ${_reason(e)}');
      }
      debugPrint('avatar artıkları temizlenemedi: $e');
    }
  }

  static String _reason(Object e) =>
      e is PostgrestException ? e.message : e.toString();

  Future<void> sendRequest(String userId) async {
    final String? uid = _uid;
    if (uid == null || uid == userId) return;
    await _client.from('friendships').insert(<String, dynamic>{
      'requester_id': uid,
      'addressee_id': userId,
      'status': 'pending',
    });
  }

  /// Bana gelen isteği kabul eder.
  Future<void> acceptRequest(String requesterId) async {
    final String? uid = _uid;
    if (uid == null) return;
    await _client
        .from('friendships')
        .update(<String, dynamic>{'status': 'accepted'})
        .eq('requester_id', requesterId)
        .eq('addressee_id', uid);
  }

  /// İsteği reddeder / iptal eder / arkadaşlığı siler (iki yön de denenir).
  Future<void> removeRelation(String otherId) async {
    final String? uid = _uid;
    if (uid == null) return;
    await _client
        .from('friendships')
        .delete()
        .eq('requester_id', uid)
        .eq('addressee_id', otherId);
    await _client
        .from('friendships')
        .delete()
        .eq('requester_id', otherId)
        .eq('addressee_id', uid);
  }
}

final SocialRepository socialRepository = SocialRepository.instance;

/// İmzalı URL ölmeden önce yenilemek için bırakılan pay.
const Duration _kSignedUrlMargin = Duration(seconds: 60);

/// Önbelleklenmiş imzalı URL + son kullanma zamanı.
///
/// Son kullanma zamanını tutmak şart: imzalı adresler kısa ömürlü, önbellek ise
/// eskiden süresizdi. İkisi ayrı yaşadığı sürece uzun oturumlarda görseller
/// sessizce kırılıyor.
class _SignedUrl {
  const _SignedUrl(this.url, this.expiresAt);

  final String url;
  final DateTime expiresAt;

  bool get isStale =>
      DateTime.now().isAfter(expiresAt.subtract(_kSignedUrlMargin));
}

/// Profil fotoğrafı işlemlerinde kullanıcıya gösterilebilir hata.
///
/// Bu akış eskiden hatayı yutup null dönüyordu; "yükledim ama görünmüyor"
/// durumunun sebebi ne kullanıcıya ne de günlüğe ulaşıyordu.
class AvatarException implements Exception {
  const AvatarException(this.message);

  final String message;

  @override
  String toString() => message;
}
