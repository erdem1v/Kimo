import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/report_reason.dart';

/// Arkadaş kodu, engelleme ve gelen soru şikâyeti.
///
/// Arkadaş ekleme artık TAKMA AD ARAMASIYLA DEĞİL, kodla yapılıyor. Kod bir
/// sırdır: paylaşmadığın kimse seni bulamaz. Bu, Task 01'in açık bıraktığı
/// "dizin toplu dökülebiliyor" riskinin ürün tarafındaki cevabı.
class FriendRepository {
  FriendRepository._();
  static final FriendRepository instance = FriendRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Kendi arkadaş kodum, `XXX-XXX` biçiminde gösterime hazır.
  Future<String?> myCode() async {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('profiles')
          .select('friend_code')
          .eq('id', uid)
          .limit(1);
      if (rows.isEmpty) return null;
      return formatCode(rows.first['friend_code'] as String?);
    } catch (e) {
      debugPrint('arkadaş kodu okunamadı: $e');
      return null;
    }
  }

  /// Depolanan kod tiresizdir; gösterimde ortadan bölünür.
  static String? formatCode(String? raw) {
    if (raw == null || raw.length != 6) return raw;
    return '${raw.substring(0, 3)}-${raw.substring(3)}';
  }

  /// Kodla arkadaş isteği gönderir.
  ///
  /// Başarısızlık İSTİSNA DEĞİL, dönüş değeri. Sebebi sunucu tarafında:
  /// PostgreSQL'de istisna işlemi geri alır ve oran sınırı sayacını da siler,
  /// yani geçersiz denemeler hiç sayılmaz ve kod uzayı bedavaya taranırdı.
  ///
  /// Sunucu "kod yok", "kendi kodun", "engellisin" ve "anonim hesap" arasında
  /// AYRIM YAPMIYOR — hepsi `bulunamadi`. Aksi hâlde kod uzayını taramak için
  /// bir sızıntı kanalı olurdu.
  ///
  /// İstisna yalnızca yapısal hatalarda gelir: oturum yok (28000), kod
  /// uzunluğu yanlış (22023), deneme sınırı aşıldı (54000).
  Future<AddFriendResult> addByCode(String code) async {
    final dynamic res = await _client.rpc<dynamic>(
      'add_friend_by_code',
      params: <String, dynamic>{'p_code': code},
    );
    final Map<String, dynamic> row = res is List && res.isNotEmpty
        ? (res.first as Map).cast<String, dynamic>()
        : (res is Map ? res.cast<String, dynamic>() : <String, dynamic>{});
    return AddFriendResult(
      ok: row['ok'] == true,
      reason: row['reason'] as String? ?? 'bulunamadi',
      nickname: row['nickname'] as String?,
    );
  }

  /// Kodu yeniler (günde bir kez). Taciz durumunda kaçış yolu.
  Future<String?> rotateCode() async {
    final dynamic res = await _client.rpc<dynamic>('rotate_friend_code');
    return formatCode(res as String?);
  }

  /// Ortak arkadaş sayısı. Kimlik değil yalnızca SAYI döner.
  Future<int> mutualFriends(String userId) async {
    try {
      final dynamic res = await _client.rpc<dynamic>(
        'mutual_friend_count',
        params: <String, dynamic>{'p_user': userId},
      );
      return (res as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('ortak arkadaş sayısı okunamadı: $e');
      return 0;
    }
  }

  /// Kullanıcıyı engeller: bir daha soru gönderemez, arkadaş isteği atamaz.
  /// Engellenen kişiye bildirim GİTMEZ ve engellendiğini göremez.
  Future<void> block(String userId) async {
    await _client.rpc<void>(
      'block_user',
      params: <String, dynamic>{'p_user': userId},
    );
  }

  /// Engeli kaldırır. Ayarlardaki "Engellenen kişiler" ekranından çağrılıyor.
  ///
  /// Task 08'e kadar bu metot TANIMLIYDI ama hiçbir yerden çağrılmıyordu:
  /// kullanıcı birini engelleyebiliyor, engellediklerini göremiyor ve geri
  /// alamıyordu (A-8). Sunucu tarafı 0044'ten beri hazırdı.
  Future<void> unblock(String userId) async {
    await _client.rpc<void>(
      'unblock_user',
      params: <String, dynamic>{'p_user': userId},
    );
  }

  /// Engellediğim kişiler — takma adlarıyla.
  ///
  /// `profiles_public` üzerinden okunmuyor: o görünüm anonim ve sistem
  /// hesaplarını süzüyor (0047), yani engellediğin anonim biri listede
  /// BOŞLUK olarak görünürdü ve engeli kaldıramazdın. Ayrıca görünüm 0068'de
  /// istemciye tamamen kapandı. `my_blocked_users()` süzgeçsiz okuyor ve
  /// yalnızca çağıranın listesini döndürüyor.
  Future<List<BlockedUser>> blockedUsers() async {
    final List<dynamic> rows =
        await _client.rpc<List<dynamic>>('my_blocked_users');
    return rows
        .map((dynamic r) => BlockedUser.fromRow((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Gelen bir soruyu şikâyet eder; istenirse göndereni de engeller.
  ///
  /// Tek çağrı: iki ayrı istek olsaydı ikincisi düştüğünde kullanıcı
  /// "engelledim" sanıp engellememiş olurdu.
  Future<void> reportReceived({
    required String sendId,
    required ReportReason reason,
    String? note,
    bool block = false,
  }) async {
    await _client.rpc<void>(
      'report_received_question',
      params: <String, dynamic>{
        'p_send': sendId,
        'p_reason': reason.dbValue,
        'p_note': note,
        'p_block': block,
      },
    );
  }
}

/// Kodla ekleme sonucu.
@immutable
/// Engellenen bir kişinin listede gösterilen bilgisi.
///
/// Avatar BİLEREK YOK: engellenen kişinin fotoğrafını göstermek için bir sebep
/// yok, baş harf yeterli (`UserAvatar` zaten ona düşüyor).
class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.nickname,
    required this.blockedAt,
  });

  final String id;
  final String nickname;
  final DateTime blockedAt;

  factory BlockedUser.fromRow(Map<String, dynamic> row) => BlockedUser(
        id: row['id'] as String,
        nickname: (row['nickname'] as String?) ?? 'Öğrenci',
        blockedAt: DateTime.tryParse(row['blocked_at'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
      );
}

class AddFriendResult {
  const AddFriendResult({
    required this.ok,
    required this.reason,
    this.nickname,
  });

  final bool ok;

  /// Sunucunun döndürdüğü sebep kodu:
  /// `eklendi` · `bulunamadi` · `onay_bekleniyor`.
  ///
  /// **Metin DEĞİL, kod.** Kullanıcıya gösterilecek cümleyi arayüz kuruyor
  /// (`friends_view.dart`): veri katmanında Türkçe cümle üretmek, o cümleleri
  /// yerelleştirme dosyasının dışında bırakıyordu.
  final String reason;

  final String? nickname;
}

final FriendRepository friendRepository = FriendRepository.instance;
