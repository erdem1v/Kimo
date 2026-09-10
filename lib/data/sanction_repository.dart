import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Askının kullanıcıya nasıl anlatılacağını belirleyen üç durum.
///
/// Enum, metnin KENDİSİ değil: ekran bunu yerelleştirilmiş dizeye çeviriyor.
/// Ayrım burada durunca saf birim testiyle sınanabiliyor (depoda Supabase
/// sahtelemesi yok) ve sunucudan gelen `reason_code` hiçbir zaman doğrudan
/// kullanıcıya gösterilmiyor.
enum SanctionKind {
  /// Yaptırım yok.
  none,

  /// Süreli askı — bitiş tarihi var.
  temporary,

  /// Kalıcı yasak — bitiş tarihi yok.
  permanent,
}

/// Kullanıcının kendi yaptırım durumu (`my_sanction`).
@immutable
class SanctionStatus {
  const SanctionStatus({
    required this.suspended,
    required this.permanent,
    this.until,
    this.reasonCode,
  });

  final bool suspended;
  final bool permanent;
  final DateTime? until;

  /// Sunucudaki kapalı küme: photo_repeat · abuse · spam · other.
  final String? reasonCode;

  static const SanctionStatus none =
      SanctionStatus(suspended: false, permanent: false);

  /// Süresiz ama kalıcı olmayan bir askı da [SanctionKind.temporary] sayılır:
  /// yönetici kaldırabilir, yani kullanıcıya "kalıcı" demek yanlış olurdu.
  SanctionKind get kind {
    if (!suspended) return SanctionKind.none;
    return permanent ? SanctionKind.permanent : SanctionKind.temporary;
  }

  factory SanctionStatus.fromRow(Map<String, dynamic> row) {
    final Object? until = row['until'];
    return SanctionStatus(
      suspended: row['suspended'] == true,
      permanent: row['permanent'] == true,
      until: until is String ? DateTime.tryParse(until)?.toLocal() : null,
      reasonCode: row['reason_code'] as String?,
    );
  }
}

/// Uyarının sertliği. Task 07'nin kademeli yaptırım tablosu.
enum WarningTone {
  /// Birinci ihlal: nazik.
  gentle,

  /// İkinci ihlal: sert.
  firm,

  /// Üçüncü ve sonrası: hesap askıya alındı.
  suspended,
}

/// Kullanıcıya gösterilmemiş bir içerik ihlali (`my_photo_warnings`).
@immutable
class PhotoWarning {
  const PhotoWarning({
    required this.id,
    required this.strikeNo,
    required this.activeCount,
    this.mistakeId,
  });

  final String id;

  /// Kayıt anındaki sıra. Sertlik BUNDAN seçiliyor, güncel sayaçtan değil:
  /// kullanıcının gördüğü metin, uyarının yazıldığı ana ait olmalı.
  final int strikeNo;

  /// 180 günlük penceredeki güncel ihlal sayısı (yönetici olmayan gösterim).
  final int activeCount;

  final String? mistakeId;

  WarningTone get tone => switch (strikeNo) {
        <= 1 => WarningTone.gentle,
        2 => WarningTone.firm,
        _ => WarningTone.suspended,
      };

  factory PhotoWarning.fromRow(Map<String, dynamic> row) {
    return PhotoWarning(
      id: row['id'] as String,
      strikeNo: (row['strike_no'] as num?)?.toInt() ?? 1,
      activeCount: (row['active_count'] as num?)?.toInt() ?? 1,
      mistakeId: row['mistake_id'] as String?,
    );
  }
}

/// Askı ve içerik ihlali okumaları.
///
/// Kararların HİÇBİRİ burada verilmiyor: eşik, pencere ve merdiven sunucuda
/// (göç 0062). Bu sınıf yalnızca sunucunun verdiği kararı okuyup gösteriyor —
/// kotada olduğu gibi, kuralın iki yerde yaşadığı yanılsamasından kaçınmak için.
class SanctionRepository {
  SanctionRepository._();
  static final SanctionRepository instance = SanctionRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Kendi askı durumu. Okunamazsa `null` — çağıran kullanıcıyı YANLIŞLIKLA
  /// askı ekranına düşürmüyor; ağ hatası bir yaptırım değildir.
  Future<SanctionStatus?> mySanction() async {
    try {
      final dynamic res = await _client.rpc<dynamic>('my_sanction');
      if (res is List && res.isNotEmpty) {
        return SanctionStatus.fromRow(
            (res.first as Map).cast<String, dynamic>());
      }
      if (res is Map) {
        return SanctionStatus.fromRow(res.cast<String, dynamic>());
      }
      return SanctionStatus.none;
    } catch (e) {
      debugPrint('askı durumu okunamadı: $e');
      return null;
    }
  }

  /// Henüz gösterilmemiş içerik uyarıları. Hata sessiz: uyarı gösterememek
  /// akışı durdurmamalı, süpürücü ve bir sonraki açılış aynı satırı bulur.
  Future<List<PhotoWarning>> pendingWarnings() async {
    try {
      final dynamic res = await _client.rpc<dynamic>('my_photo_warnings');
      if (res is! List) return const <PhotoWarning>[];
      return res
          .map((dynamic r) =>
              PhotoWarning.fromRow((r as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('içerik uyarıları okunamadı: $e');
      return const <PhotoWarning>[];
    }
  }

  /// Uyarıları "görüldü" işaretler. Sayaca DOKUNMUYOR (sunucu tarafında da
  /// dokunamaz): yalnızca aynı uyarının her açılışta tekrar çıkmasını önler.
  Future<void> acknowledgeWarnings() async {
    try {
      await _client.rpc<void>('ack_photo_warnings');
    } catch (e) {
      debugPrint('uyarılar işaretlenemedi: $e');
    }
  }
}

final SanctionRepository sanctionRepository = SanctionRepository.instance;
