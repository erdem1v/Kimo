import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/crash_service.dart';
import '../models/models.dart';
import '../models/report_reason.dart';

/// İncelenmeyi bekleyen bir şikayet (admin kuyruğu).
class PendingReport {
  const PendingReport({
    required this.reportId,
    required this.mistakeId,
    required this.reason,
    required this.subject,
    required this.concept,
    required this.ownerNickname,
    required this.reportCount,
    required this.createdAt,
    this.note,
    this.photoPath,
    this.options = const <QuestionOption>[],
    this.correctIndex,
  });

  final String reportId;
  final String mistakeId;
  final ReportReason reason;
  final String? note;
  final String subject;
  final String concept;
  final String ownerNickname;
  final int reportCount;
  final DateTime createdAt;
  final String? photoPath;
  final List<QuestionOption> options;
  final int? correctIndex;

  factory PendingReport.fromRow(Map<String, dynamic> row) {
    final dynamic raw = row['options'];
    return PendingReport(
      reportId: row['report_id'] as String,
      mistakeId: row['mistake_id'] as String,
      reason: ReportReason.fromDb(row['reason'] as String?),
      note: row['note'] as String?,
      subject: (row['subject'] as String?) ?? '',
      concept: (row['concept'] as String?) ?? '',
      ownerNickname: (row['owner_nickname'] as String?) ?? 'Bir öğrenci',
      reportCount: (row['report_count'] as int?) ?? 0,
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      photoPath: row['photo_path'] as String?,
      options: raw is List
          ? raw
              .map((dynamic o) =>
                  QuestionOption.fromJson((o as Map).cast<String, dynamic>()))
              .toList()
          : const <QuestionOption>[],
      correctIndex: row['correct_index'] as int?,
    );
  }

  // Eşleme artık modelde: iki yerde tutulması, yeni bir sebep eklendiğinde
  // moderasyon ekranının onu 'other' göstermesine yol açıyordu.
}

/// Moderasyon: bekleyen şikayetleri getirir ve karar uygular. Tüm yetki
/// kontrolü veritabanında (is_admin) yapılır.
class ModerationRepository {
  ModerationRepository._();
  static final ModerationRepository instance = ModerationRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Oturumdaki kullanıcı moderatör mü?
  Future<bool> isAdmin() async {
    try {
      final dynamic v = await _client.rpc<dynamic>('is_admin');
      return v == true;
    } catch (e, st) {
      // Ağ hatası "admin değil" ile aynı görünür — admin olmayan çoğunluk
      // için doğru varsayılan; yine de iz bırak.
      unawaited(reportError(e, st, context: 'moderation.isAdmin'));
      return false;
    }
  }

  Future<List<PendingReport>> pending() async {
    final List<dynamic> rows =
        await _client.rpc<List<dynamic>>('admin_pending_reports');
    return rows
        .map((dynamic r) =>
            PendingReport.fromRow((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// [remove] true ise içerik kalıcı olarak yayından çıkar; false ise şikâyet haksız
  /// sayılır ve soru geri döner.
  Future<void> decide(String reportId, {required bool remove}) async {
    await _client.rpc<void>('moderate_report', params: <String, dynamic>{
      'p_report': reportId,
      'p_action': remove ? 'remove' : 'dismiss',
    });
  }

  static const String _photoBucket = 'mistake-photos';

  /// Kaldırılan içeriğin depolama nesnesini SİLER ve satırı işaretler.
  ///
  /// Karar `moderation='removed'` yazdığı andan itibaren yeni imzalı adres
  /// üretilemiyor (0030 göçü). Ama halihazırda dağıtılmış adresler ömürleri
  /// boyunca çalışmaya devam eder — Değişmez 3 onları da kapsıyor, o yüzden
  /// dosyanın kendisi siliniyor.
  ///
  /// Bu adım başarısız olursa satır `admin_photo_purge_queue()` kuyruğunda
  /// kalır; sessizce kaybolmaz.
  Future<void> purgePhoto(String mistakeId, String? photoPath) async {
    if (photoPath == null || photoPath.isEmpty) return;
    await _client.storage.from(_photoBucket).remove(<String>[photoPath]);
    await _client.rpc<void>(
      'admin_mark_photo_purged',
      params: <String, dynamic>{'p_id': mistakeId},
    );
  }

  /// Makine taramasının şüpheli bulduğu fotoğraflar (0050 — admin incelemesi).
  Future<List<FlaggedPhoto>> flaggedPhotos() async {
    final dynamic rows = await _client.rpc<dynamic>('admin_flagged_photos');
    if (rows is! List) return const <FlaggedPhoto>[];
    return <FlaggedPhoto>[
      for (final dynamic r in rows)
        FlaggedPhoto.fromRow((r as Map).cast<String, dynamic>()),
    ];
  }

  /// Şüpheli fotoğraf kararı: [clear] = yanlış pozitif (paylaşıma açılır);
  /// değilse içerik yayından kaldırılır (mevcut purge kuyruğuna düşer —
  /// çağıran ardından [purgePhoto] ile dosyayı da silmeli).
  Future<void> reviewPhotoScan(String mistakeId, {required bool clear}) async {
    await _client.rpc<void>(
      'admin_review_photo_scan',
      params: <String, dynamic>{
        'p_id': mistakeId,
        'p_action': clear ? 'clear' : 'remove',
      },
    );
  }

  /// Bir kullanıcının yaptırım geçmişi ve ihlal sayaçları.
  ///
  /// Yetki SUNUCUDA doğrulanıyor (`is_admin()`); yönetici olmayan çağıran boş
  /// liste alır, hata almaz — `admin_flagged_photos` ile aynı desen.
  Future<List<UserSanction>> userSanctions(String userId) async {
    final dynamic rows = await _client.rpc<dynamic>(
      'admin_user_sanctions',
      params: <String, dynamic>{'p_user': userId},
    );
    if (rows is! List) return const <UserSanction>[];
    return <UserSanction>[
      for (final dynamic r in rows)
        UserSanction.fromRow((r as Map).cast<String, dynamic>()),
    ];
  }

  /// Kullanıcıyı askıya alır, yasaklar ya da yaptırımı kaldırır.
  ///
  /// [days] yalnızca `suspend` için anlamlı; verilmezse askı SÜRESİZ olur
  /// (yönetici kaldırana kadar). Hata YUTULMUYOR: yaptırım kararının sessizce
  /// düşmesi, verilmemiş olmasından kötü.
  Future<void> sanctionUser(
    String userId, {
    required String action,
    int? days,
    String reason = 'abuse',
    String? note,
  }) async {
    await _client.rpc<void>(
      'admin_suspend_user',
      params: <String, dynamic>{
        'p_user': userId,
        'p_action': action,
        'p_days': days,
        'p_reason': reason,
        'p_note': note,
      },
    );
  }

  /// Nesnesi hâlâ duran kaldırılmış içerikler (yarım kalan temizlikler).
  Future<List<({String mistakeId, String photoPath})>> pendingPurges() async {
    final List<dynamic> rows =
        await _client.rpc<List<dynamic>>('admin_photo_purge_queue');
    return <({String mistakeId, String photoPath})>[
      for (final dynamic r in rows)
        (
          mistakeId: (r as Map)['mistake_id'] as String,
          photoPath: r['photo_path'] as String,
        ),
    ];
  }
}

final ModerationRepository moderationRepository = ModerationRepository.instance;

/// Makine taramasının şüpheli bulduğu bir fotoğraf (admin kuyruğu).
class FlaggedPhoto {
  const FlaggedPhoto({
    required this.mistakeId,
    required this.ownerId,
    required this.photoPath,
    required this.subject,
    required this.concept,
    this.flaggedAt,
  });

  final String mistakeId;

  /// Yaptırım kararı KULLANICIYA veriliyor, içeriğe değil (Task 07): kuyruk
  /// satırından doğrudan askıya alabilmek için sahibin kimliği gerekli.
  /// `admin_flagged_photos` bunu zaten döndürüyordu, model taşımıyordu.
  final String ownerId;

  final String? photoPath;
  final String subject;
  final String concept;
  final DateTime? flaggedAt;

  factory FlaggedPhoto.fromRow(Map<String, dynamic> row) => FlaggedPhoto(
        mistakeId: row['mistake_id'] as String,
        ownerId: (row['owner_id'] as String?) ?? '',
        photoPath: row['photo_path'] as String?,
        subject: (row['subject'] as String?) ?? '',
        concept: (row['concept'] as String?) ?? '',
        flaggedAt: row['flagged_at'] is String
            ? DateTime.tryParse(row['flagged_at'] as String)
            : null,
      );
}

/// Bir kullanıcının yaptırım defterindeki tek satır (`admin_user_sanctions`).
class UserSanction {
  const UserSanction({
    required this.action,
    required this.source,
    required this.reasonCode,
    required this.createdAt,
    required this.violations180d,
    required this.violationsAll,
    this.until,
    this.note,
    this.voidedAt,
  });

  /// suspend · ban · lift
  final String action;

  /// auto_photo (tarama) · admin (elle)
  final String source;

  final String reasonCode;
  final DateTime createdAt;

  /// Otomatik eşiğin baktığı 180 günlük pencere sayacı.
  final int violations180d;

  /// Ömür boyu sayaç. Otomatik karar pencereye bakıyor; İNSAN kararı tam
  /// geçmişi görebilmeli — ikisi bilerek ayrı.
  final int violationsAll;

  final DateTime? until;
  final String? note;
  final DateTime? voidedAt;

  bool get voided => voidedAt != null;

  static DateTime? _at(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  factory UserSanction.fromRow(Map<String, dynamic> row) => UserSanction(
        action: (row['action'] as String?) ?? '',
        source: (row['source'] as String?) ?? '',
        reasonCode: (row['reason_code'] as String?) ?? '',
        createdAt: _at(row['created_at']) ?? DateTime.now(),
        violations180d: (row['violations_180d'] as num?)?.toInt() ?? 0,
        violationsAll: (row['violations_all'] as num?)?.toInt() ?? 0,
        until: _at(row['until']),
        note: row['note'] as String?,
        voidedAt: _at(row['voided_at']),
      );
}

/// Yönetim ekranındaki bir soru (moderatör tüm kullanıcıların sorularını
/// görür ve düzeltebilir).
class AdminQuestion {
  const AdminQuestion({
    required this.id,
    required this.subject,
    required this.concept,
    required this.ownerNickname,
    required this.isPublic,
    required this.moderation,
    required this.reportCount,
    this.exam,
    this.photoPath,
    this.options = const <QuestionOption>[],
    this.correctIndex,
    this.extraConcepts = const <String>[],
    this.photoScan = 'clear',
    this.curriculum = 'eski',
  });

  final String id;
  final String subject;
  final String concept;
  final String? exam;
  final String ownerNickname;
  final bool isPublic;
  final String moderation; // ok | hidden | removed
  final int reportCount;
  final String? photoPath;
  final List<QuestionOption> options;
  final int? correctIndex;

  /// Sorunun ayrıca değdiği konular.
  final List<String> extraConcepts;

  /// Makine taramasının durumu: `pending` | `clear` | `flagged` |
  /// `unsupported` (göç 0066).
  ///
  /// Yönetici listesinde GÖRÜNÜYOR çünkü `admin_review_photo_scan(id,'clear')`
  /// durumdan bağımsız çalışıyor: hiç taranmamış bir fotoğrafı paylaşıma
  /// açmak mümkün ve bunun bilerek yapılması gerekiyor.
  final String photoScan;

  /// Sorunun KENDİ müfredatı (`eski` | `maarif`, göç 0071).
  ///
  /// Konu geçerliliği buna göre denetleniyor. Task 09'a kadar moderatörün
  /// kendi müfredatı kullanılıyordu ve maarif öğrencisinin doğru kaydı, eski
  /// müfredatlı bir moderatöre "müfredatta karşılığı yok" görünüyordu.
  final String curriculum;

  factory AdminQuestion.fromRow(Map<String, dynamic> row) {
    final dynamic raw = row['options'];
    return AdminQuestion(
      id: row['id'] as String,
      subject: (row['subject'] as String?) ?? '',
      concept: (row['concept'] as String?) ?? '',
      exam: row['exam'] as String?,
      ownerNickname: (row['owner_nickname'] as String?) ?? '—',
      isPublic: row['is_public'] == true,
      moderation: (row['moderation'] as String?) ?? 'ok',
      reportCount: (row['report_count'] as int?) ?? 0,
      photoPath: row['photo_path'] as String?,
      photoScan: (row['photo_scan'] as String?) ?? 'clear',
      curriculum: (row['curriculum'] as String?) ?? 'eski',
      options: raw is List
          ? raw
              .map((dynamic o) =>
                  QuestionOption.fromJson((o as Map).cast<String, dynamic>()))
              .toList()
          : const <QuestionOption>[],
      correctIndex: row['correct_index'] as int?,
      extraConcepts: (row['extra_concepts'] as List<dynamic>?)
              ?.map((dynamic e) => e as String)
              .toList() ??
          const <String>[],
    );
  }
}

/// Moderatörün tüm soruları görüp düzeltebildiği katman.
extension AdminQuestions on ModerationRepository {
  SupabaseClient get _c => Supabase.instance.client;

  Future<List<AdminQuestion>> allQuestions({int limit = 300}) async {
    final List<dynamic> rows = await _c.rpc<List<dynamic>>(
      'admin_all_questions',
      params: <String, dynamic>{'p_limit': limit, 'p_offset': 0},
    );
    return rows
        .map((dynamic r) =>
            AdminQuestion.fromRow((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Ders/konu/sınav (ve gerekirse doğru şık) düzeltir; bağlı ölçümler de
  /// veritabanında güncellenir.
  Future<void> updateQuestion(
    String id, {
    String? subject,
    String? concept,
    String? exam,
    int? correctIndex,
    List<String>? extraConcepts,
  }) async {
    await _c.rpc<void>('admin_update_question', params: <String, dynamic>{
      'p_id': id,
      'p_subject': subject,
      'p_concept': concept,
      'p_exam': exam,
      'p_correct_index': correctIndex,
      // Boş liste "ek konu yok" demek; null ise dokunulmaz.
      'p_extra_concepts': extraConcepts,
    });
  }

  /// 'hide' yayından çıkarır, 'restore' geri alır, 'delete' tamamen siler.
  Future<void> questionAction(String id, String action) async {
    await _c.rpc<void>('admin_question_action',
        params: <String, dynamic>{'p_id': id, 'p_action': action});
  }
}
