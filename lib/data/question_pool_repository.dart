import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/public_question.dart';

/// Soru havuzu: kullanıcıların paylaşıma açtığı hataları rastgele getirir ve
/// çözüm denemelerini kaydeder.
class QuestionPoolRepository {
  QuestionPoolRepository._();
  static final QuestionPoolRepository instance = QuestionPoolRepository._();

  SupabaseClient get _client => Supabase.instance.client;
  static const String _bucket = 'mistake-photos';

  /// Rastgele havuz soruları (kendi soruların ve daha önce çözdüklerin hariç).
  Future<List<PublicQuestion>> fetchRandom({int limit = 10}) async {
    final List<dynamic> rows = await _client.rpc<List<dynamic>>(
      'random_public_questions',
      params: <String, dynamic>{'p_limit': limit},
    );
    return rows
        .map((dynamic r) =>
            PublicQuestion.fromRow((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Havuz sorusunun fotoğrafı için imzalı URL.
  Future<String?> signedUrl(String path) async {
    try {
      return await _client.storage.from(_bucket).createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
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
