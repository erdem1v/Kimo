import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/public_question.dart';
import '../models/received_question.dart';
import '../models/report_reason.dart';

/// Soru havuzu: kullanıcıların paylaşıma açtığı hataları rastgele getirir ve
/// çözüm denemelerini kaydeder.
class QuestionPoolRepository {
  QuestionPoolRepository._();
  static final QuestionPoolRepository instance = QuestionPoolRepository._();

  SupabaseClient get _client => Supabase.instance.client;
  static const String _bucket = 'mistake-photos';

  /// Rastgele havuz soruları (kendi soruların ve daha önce çözdüklerin hariç).
  /// [subject] verilirse yalnızca o dersten, [concept] de verilirse yalnızca
  /// o konudan gelir (harita üzerinden konu testi).
  Future<List<PublicQuestion>> fetchRandom({
    int limit = 10,
    String? subject,
    String? concept,
  }) async {
    final List<dynamic> rows = subject == null
        ? await _client.rpc<List<dynamic>>(
            'random_public_questions',
            params: <String, dynamic>{'p_limit': limit},
          )
        : await _client.rpc<List<dynamic>>(
            'random_questions_by_topic',
            params: <String, dynamic>{
              'p_subject': subject,
              'p_concept': concept,
              'p_limit': limit,
            },
          );
    return rows
        .map((dynamic r) =>
            PublicQuestion.fromRow((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Konu başına çözülebilir soru sayısı: 'Ders|Konu' → adet. Haritada boş
  /// konuya tıklanmasın diye önceden gösterilir.
  Future<Map<String, int>> availableCounts() async {
    try {
      final List<dynamic> rows =
          await _client.rpc<List<dynamic>>('available_question_counts');
      return <String, int>{
        for (final dynamic r in rows)
          '${(r as Map)['subject']}|${r['concept']}': (r['cnt'] as int?) ?? 0,
      };
    } catch (_) {
      return <String, int>{};
    }
  }

  /// Havuz sorusunun fotoğrafı için imzalı URL.
  Future<String?> signedUrl(String path) async {
    try {
      return await _client.storage.from(_bucket).createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------ arkadaşa soru gönderme

  /// Bir soruyu arkadaşlara gönderir. Arkadaşlık kontrolü RLS'te zorunludur.
  /// Zaten gönderilmiş olanlar sessizce atlanır.
  Future<int> sendToFriends({
    required String mistakeId,
    required List<String> receiverIds,
    String? note,
  }) async {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null || receiverIds.isEmpty) return 0;
    int sent = 0;
    for (final String receiver in receiverIds) {
      try {
        await _client.from('question_sends').insert(<String, dynamic>{
          'sender_id': uid,
          'receiver_id': receiver,
          'mistake_id': mistakeId,
          'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
        });
        sent++;
      } catch (_) {
        // Aynı soruyu aynı kişiye ikinci kez göndermek (unique) ya da ağ hatası.
      }
    }
    return sent;
  }

  /// Bana gelen sorular (en yeni önce).
  Future<List<ReceivedQuestion>> received({bool onlyUnsolved = false}) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('received_questions')
        .select()
        .order('created_at', ascending: false);
    final List<ReceivedQuestion> items =
        rows.map(ReceivedQuestion.fromRow).toList();
    if (!onlyUnsolved) return items;
    return items.where((ReceivedQuestion q) => !q.solved).toList();
  }

  /// Çözülmemiş gelen soru sayısı (rozet için).
  Future<int> unsolvedCount() async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('received_questions')
          .select('send_id')
          .filter('solved_at', 'is', null);
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  /// Gelen soruyu çözüldü olarak işaretler.
  Future<void> markSolved(String sendId, bool correct) async {
    try {
      await _client.from('question_sends').update(<String, dynamic>{
        'solved_at': DateTime.now().toIso8601String(),
        'correct': correct,
      }).eq('id', sendId);
    } catch (_) {
      // Akışı bloklamayalım.
    }
  }

  /// Soruyu şikayet eder. Eşiğe ulaşan sorular veritabanındaki trigger ile
  /// havuzdan düşer; şikayet ettiğin soru sana bir daha gösterilmez.
  Future<void> report({
    required String questionId,
    required ReportReason reason,
    String? note,
  }) async {
    await _client.from('question_reports').insert(<String, dynamic>{
      'mistake_id': questionId,
      'reason': reason.dbValue,
      'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    });
  }

  /// Çözüm denemesini kaydeder (kullanıcı başına soru başına bir kez sayılır).
  Future<void> recordAttempt(String questionId, bool correct) async {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _client.from('question_attempts').insert(<String, dynamic>{
        'mistake_id': questionId,
        'user_id': uid,
        'correct': correct,
      });
    } catch (_) {
      // Aynı soruyu tekrar çözmek sayaçları ikinci kez artırmasın (pk çakışması)
      // ya da ağ hatası olabilir; akışı bloklamayalım.
    }
  }
}

final QuestionPoolRepository questionPoolRepository =
    QuestionPoolRepository.instance;
