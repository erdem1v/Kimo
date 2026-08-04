import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Hata bankasının Supabase uygulaması: `mistakes` tablosu + `mistake-photos`
/// (özel) storage bucket'ı + `analyze-question` Edge Function (AI Gateway).
class MistakeRepository {
  MistakeRepository._();
  static final MistakeRepository instance = MistakeRepository._();

  static const String _bucket = 'mistake-photos';

  SupabaseClient get _client => Supabase.instance.client;

  /// Kullanıcının hatalarını (en yeni önce) getirir.
  Future<List<MistakeEntry>> fetch() async {
    final List<Map<String, dynamic>> rows = await _client
        .from('mistakes')
        .select()
        .order('created_at', ascending: false);

    final List<MistakeEntry> result = <MistakeEntry>[];
    for (final Map<String, dynamic> row in rows) {
      final String? path = row['photo_path'] as String?;
      String? url;
      if (path != null) {
        url = await _client.storage.from(_bucket).createSignedUrl(path, 3600);
      }

      final dynamic rawOptions = row['options'];
      List<QuestionOption>? options;
      if (rawOptions is List) {
        options = rawOptions
            .map((dynamic o) =>
                QuestionOption.fromJson((o as Map).cast<String, dynamic>()))
            .toList();
      }

      result.add(
        MistakeEntry(
          subject: row['subject'] as String,
          concept: row['concept'] as String,
          type: MistakeType.fromDb(row['mistake_type'] as String),
          note: (row['note'] as String?) ?? '',
          date: DateTime.parse(row['created_at'] as String),
          hasPhoto: path != null,
          photoUrl: url,
          options: options,
          correctIndex: row['correct_index'] as int?,
        ),
      );
    }
    return result;
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
    });
  }

  /// Fotoğrafı AI Gateway (Edge Function) ile değerlendirir: okunabilir bir
  /// soru + şıklar var mı? Geçerliyse şıkları, değilse sebebi döndürür.
  Future<QuestionAnalysis> analyzeQuestion(Uint8List imageBytes) async {
    final FunctionResponse res = await _client.functions.invoke(
      'analyze-question',
      body: <String, dynamic>{
        'imageBase64': base64Encode(imageBytes),
        'mimeType': 'image/jpeg',
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
      return QuestionAnalysis(ok: true, options: options);
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
}

final MistakeRepository mistakeRepository = MistakeRepository.instance;
