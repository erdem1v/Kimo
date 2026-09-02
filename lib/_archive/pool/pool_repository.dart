import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_yks_coach/data/question_send_repository.dart' show AnswerResult;
import 'package:ai_yks_coach/data/submission_queue.dart';

import 'public_question.dart';

/// ARŞİV — soru havuzu veri katmanı.
///
/// Havuz bu sürümde arayüzden çıkarıldı (bkz. `lib/_archive/README.md`).
/// Dosya SİLİNMEDİ: havuz ileride elden geçirilip geri gelecek ve sıfırdan
/// tasarlanması istenmiyor. Analize dâhil değil, hiçbir yerden çağrılmıyor.
///
/// Sunucu tarafı (görünüm ve RPC'ler) yerinde duruyor; istemci çağırmadığı
/// sürece zararsızlar ve şemayı bozmadan geri açılabilirler.
class PoolRepository {
  PoolRepository._();
  static final PoolRepository instance = PoolRepository._();

  SupabaseClient get _client => Supabase.instance.client;

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
        .map(
          (dynamic r) =>
              PublicQuestion.fromRow((r as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  /// Konu başına çözülebilir soru sayısı: 'Ders|Konu' → adet. Haritada boş
  /// konuya tıklanmasın diye önceden gösterilir.
  Future<Map<String, int>> availableCounts() async {
    try {
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'available_question_counts',
      );
      return <String, int>{
        for (final dynamic r in rows)
          '${(r as Map)['subject']}|${r['concept']}': (r['cnt'] as int?) ?? 0,
      };
    } catch (_) {
      return <String, int>{};
    }
  }

  /// Havuz sorusunu cevaplar.
  ///
  /// Doğruluk SUNUCUDA belirlenir. `correct_index` artık havuz yükünde
  /// gelmiyor (bkz. 0035 göçü) — yani istemci cevabı önceden bilmiyor ve
  /// "doğruluğu sunucu belirliyor" ifadesi gerçek bir anlam taşıyor.
  ///
  /// Ağ yoksa cevap KUYRUĞA alınır ve `queued` sonucu döner: sonuç o an
  /// gösterilemez (doğruluğu sunucu biliyor) ama **kaybolmaz**. Aynı soru
  /// ikinci kez XP vermediği için (`question_attempts` birincil anahtarı)
  /// tekrar gönderim güvenli.
  Future<AnswerResult> answerPoolQuestion(String mistakeId, int choice) async {
    await submissionQueue.drainIfPending();
    try {
      final dynamic res = await _client.rpc<dynamic>(
        'submit_pool_answer',
        params: <String, dynamic>{'p_mistake': mistakeId, 'p_choice': choice},
      );
      return AnswerResult.fromRpc(res);
    } on PostgrestException {
      // Sunucu YANIT VERDİ ve reddetti (ör. soru havuzda değil). Bunu
      // kuyruğa almak anlamsız: tekrar denemek de aynı sonucu verir.
      rethrow;
    } catch (_) {
      final bool queued = await submissionQueue.enqueue(<String, dynamic>{
        'kind': 'pool',
        'mistake_id': mistakeId,
        'choice': choice,
      });
      if (!queued) rethrow;
      return const AnswerResult.queued();
    }
  }
}

final PoolRepository poolRepository = PoolRepository.instance;
