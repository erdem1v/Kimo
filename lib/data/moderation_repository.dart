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
      reason: _reasonFromDb(row['reason'] as String?),
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

  static ReportReason _reasonFromDb(String? v) => switch (v) {
        'unreadable' => ReportReason.unreadable,
        'options_wrong' => ReportReason.optionsWrong,
        'answer_wrong' => ReportReason.answerWrong,
        'wrong_topic' => ReportReason.wrongTopic,
        'inappropriate' => ReportReason.inappropriate,
        'personal_info' => ReportReason.personalInfo,
        _ => ReportReason.other,
      };
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

  /// [remove] true ise soru havuzdan kalıcı çıkar; false ise şikayet haksız
  /// sayılır ve soru geri döner.
  Future<void> decide(String reportId, {required bool remove}) async {
    await _client.rpc<void>('moderate_report', params: <String, dynamic>{
      'p_report': reportId,
      'p_action': remove ? 'remove' : 'dismiss',
    });
  }
}

final ModerationRepository moderationRepository = ModerationRepository.instance;
