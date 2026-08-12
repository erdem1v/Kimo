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
  Future<void> recordAttempt({
    required String subject,
    required String concept,
    required bool correct,
    String? exam,
    String source = 'review',
  }) async {
    if (!SupabaseConfig.isConfigured) return;
    if (subject.isEmpty || concept.isEmpty) return;
    try {
      await _client.from('study_attempts').insert(<String, dynamic>{
        'subject': subject,
        'concept': concept,
        'exam': exam,
        'correct': correct,
        'source': source,
      });
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
