import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/reviews/domain/review_scheduler.dart';
import '../models/models.dart';
import '../state/user_profile.dart';

/// Hata bankasının Supabase uygulaması: `mistakes` tablosu + `mistake-photos`
/// (özel) storage bucket'ı + `analyze-question` Edge Function (AI Gateway) +
/// aralıklı tekrar planlaması (ReviewScheduler).
class MistakeRepository {
  MistakeRepository._();
  static final MistakeRepository instance = MistakeRepository._();

  static const String _bucket = 'mistake-photos';
  static const ReviewScheduler _scheduler = ReviewScheduler();

  SupabaseClient get _client => Supabase.instance.client;

  /// Kullanıcının TÜM hataları (en yeni önce) — Hatalarım ekranı için.
  Future<List<MistakeEntry>> fetch() async {
    final List<Map<String, dynamic>> rows = await _client
        .from('mistakes')
        .select()
        .order('created_at', ascending: false);
    return _mapRows(rows);
  }

  /// Bugün gözden geçirilmiş (cevaplanmış) tekrar sayısı — günlük ilerlemeyi
  /// uygulama kapansa da geri yüklemek için DB'den türetilir.
  Future<int> reviewedTodayCount() async {
    final DateTime now = DateTime.now();
    final String start =
        DateTime(now.year, now.month, now.day).toIso8601String();
    final List<Map<String, dynamic>> rows = await _client
        .from('mistakes')
        .select('id')
        .gte('last_reviewed_at', start);
    return rows.length;
  }

  /// Bugün (ve öncesi) tekrarı gelen, öğrenilmemiş hatalar — pratik için.
  Future<List<MistakeEntry>> dueReviews() async {
    final String today = _dateStr(DateTime.now());
    final List<Map<String, dynamic>> rows = await _client
        .from('mistakes')
        .select()
        .eq('mastered', false)
        .lte('next_review_date', today)
        .order('next_review_date', ascending: true);
    return _mapRows(rows);
  }

  List<MistakeEntry> _mapRows(List<Map<String, dynamic>> rows) =>
      rows.map(_mapRow).toList();

  /// Bir hatanın seçilen (sınav, ders) filtresine uyup uymadığı. Ders birebir
  /// eşleşmeli; sınavı boş (eski kayıt) olanlar her sınavda gösterilir.
  static bool matchesFilter(
    MistakeEntry e, {
    required String exam,
    required String subject,
  }) {
    if (e.subject != subject) return false;
    final String? ex = e.exam;
    return ex == null || ex.isEmpty || ex == exam;
  }

  MistakeEntry _mapRow(Map<String, dynamic> row) {
    final String? path = row['photo_path'] as String?;

    final dynamic rawOptions = row['options'];
    List<QuestionOption>? options;
    if (rawOptions is List) {
      options = rawOptions
          .map((dynamic o) =>
              QuestionOption.fromJson((o as Map).cast<String, dynamic>()))
          .toList();
    }

    return MistakeEntry(
      id: row['id'] as String?,
      subject: row['subject'] as String,
      concept: row['concept'] as String,
      type: MistakeType.fromDb(row['mistake_type'] as String),
      note: (row['note'] as String?) ?? '',
      date: DateTime.parse(row['created_at'] as String),
      hasPhoto: path != null,
      photoPath: path,
      options: options,
      correctIndex: row['correct_index'] as int?,
      step: (row['step'] as int?) ?? 0,
      lapses: (row['lapses'] as int?) ?? 0,
      mastered: row['mastered'] == true,
      isLeech: row['is_leech'] == true,
      exam: row['exam'] as String?,
    );
  }

  /// Storage'daki bir fotoğraf için kısa ömürlü imzalı URL üretir (gösterim
  /// anında, tembel). Foto silinmişse null döner.
  Future<String?> signedUrl(String path) async {
    try {
      return await _client.storage.from(_bucket).createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  /// Yeni hata ekler; fotoğraf varsa önce Storage'a yükler.
  Future<void> add({
    required String subject,
    required String concept,
    required MistakeType type,
    required String note,
    Uint8List? imageBytes,
    List<QuestionOption>? options,
    int? correctIndex,
    String? exam,
  }) async {
    String? path;
    if (imageBytes != null) {
      final String uid = _client.auth.currentUser!.id;
      path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from(_bucket).uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
    }

    await _client.from('mistakes').insert(<String, dynamic>{
      'subject': subject,
      'concept': concept,
      'mistake_type': type.dbValue,
      'note': note.isEmpty ? null : note,
      'photo_path': path,
      'options': (options == null || options.isEmpty)
          ? null
          : options.map((QuestionOption o) => o.toJson()).toList(),
      'correct_index': correctIndex,
      'exam': (exam == null || exam.isEmpty) ? null : exam,
    });
    // step/next_review_date DB varsayılanlarıyla gelir (adım 0, ertesi gün).
  }

  /// Bir tekrar sonucunu ([correct]) uygular ve planı (adım/tarih/leech/
  /// mastered) günceller.
  Future<void> submitReview(MistakeEntry entry, bool correct) async {
    final String? id = entry.id;
    if (id == null) return;
    final ReviewOutcome o = _scheduler.review(
      step: entry.step,
      lapses: entry.lapses,
      correct: correct,
      reviewedOn: DateTime.now(),
    );
    try {
      await _client.from('mistakes').update(<String, dynamic>{
        'step': o.step,
        'lapses': o.lapses,
        'is_leech': o.isLeech,
        'mastered': o.mastered,
        'next_review_date': _dateStr(o.nextReviewDate),
        'last_reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (_) {
      // Ağ hatası vb.; pratiği bloklamayalım.
    }
  }

  /// Fotoğrafı AI Gateway (Edge Function) ile değerlendirir: okunabilir bir
  /// soru + şıklar var mı? Geçerliyse şıkları, değilse sebebi döndürür.
  Future<QuestionAnalysis> analyzeQuestion(Uint8List imageBytes) async {
    final FunctionResponse res = await _client.functions.invoke(
      'analyze-question',
      body: <String, dynamic>{
        'imageBase64': base64Encode(imageBytes),
        'mimeType': 'image/jpeg',
        'curriculum': userProfile.curriculum,
      },
    );
    final dynamic data = res.data;
    if (data is! Map) {
      return const QuestionAnalysis(
          ok: false, options: <QuestionOption>[], reason: 'Analiz edilemedi.');
    }

    final bool readable = data['is_readable'] == true;
    final bool hasQuestion = data['has_question'] == true;
    final bool hasOptions = data['has_options'] == true;
    final List<QuestionOption> options = (data['options'] is List)
        ? (data['options'] as List)
            .map((dynamic o) =>
                QuestionOption.fromJson((o as Map).cast<String, dynamic>()))
            .toList()
        : <QuestionOption>[];

    final bool ok =
        readable && hasQuestion && hasOptions && options.isNotEmpty;
    if (ok) {
      final String exam = (data['sinav'] as String?)?.trim() ?? '';
      final String ders = (data['ders'] as String?)?.trim() ?? '';
      final String konu = (data['konu'] as String?)?.trim() ?? '';
      return QuestionAnalysis(
        ok: true,
        options: options,
        exam: exam.isEmpty ? null : exam,
        subject: ders.isEmpty ? null : ders,
        concept: konu.isEmpty ? null : konu,
        conceptValid: data['konu_valid'] == true,
      );
    }

    String reason = (data['reason'] as String?)?.trim() ?? '';
    if (reason.isEmpty) {
      reason = !readable
          ? 'Fotoğraf net okunmuyor.'
          : !hasQuestion
              ? 'Soru metni görünmüyor.'
              : 'Şıklar görünmüyor.';
    }
    return QuestionAnalysis(
        ok: false, options: <QuestionOption>[], reason: reason);
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final MistakeRepository mistakeRepository = MistakeRepository.instance;
