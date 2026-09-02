import 'package:supabase_flutter/supabase_flutter.dart';

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
    } catch (_) {
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

  bool get inPool => isPublic && moderation == 'ok';

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
