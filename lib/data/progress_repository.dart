import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/topic_progress.dart';
import '../services/supabase_config.dart';

/// Konu bazlı ilerleme: çözülen her sorunun konusunu kaydeder ve haritayı
/// besleyen özeti okur.
class ProgressRepository {
  ProgressRepository._();
  static final ProgressRepository instance = ProgressRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Çözülen bir soruyu kaydeder. Kaynak: 'review' (tekrar), 'pool' (havuz),
  /// 'sent' (arkadaştan gelen).
  /// [extraConcepts] verilirse ölçüm o konulara da yazılır: birden çok konuya
  /// değen bir soru çözüldüğünde haritada hepsi ilerler.
  Future<void> recordAttempt({
    required String subject,
    required String concept,
    required bool correct,
    String? exam,
    String? mistakeId,
    List<String> extraConcepts = const <String>[],
    String source = 'review',
  }) async {
    if (!SupabaseConfig.isConfigured) return;
    if (subject.isEmpty || concept.isEmpty) return;
    final List<String> concepts = <String>{concept, ...extraConcepts}
        .where((String c) => c.trim().isNotEmpty)
        .toList();
    try {
      await _client.from('study_attempts').insert(<Map<String, dynamic>>[
        for (final String c in concepts)
          <String, dynamic>{
            'subject': subject,
            'concept': c,
            'exam': exam,
            'correct': correct,
            'source': source,
            // Sorunun konusu sonradan düzeltilirse ölçüm de düzelsin diye bağ.
            'mistake_id': mistakeId,
          },
      ]);
    } catch (_) {
      // İlerleme kaydı akışı bloklamamalı.
    }
  }

  /// Konu bazlı ilerleme özetim: 'Ders|Konu' → ilerleme.
  Future<Map<String, TopicProgress>> myProgress() async {
    if (!SupabaseConfig.isConfigured) return <String, TopicProgress>{};
    final List<Map<String, dynamic>> rows =
        await _client.from('my_topic_progress').select();
    return <String, TopicProgress>{
      for (final Map<String, dynamic> r in rows)
        '${r['subject']}|${r['concept']}': TopicProgress.fromRow(r),
    };
  }
}

final ProgressRepository progressRepository = ProgressRepository.instance;
