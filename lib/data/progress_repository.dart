import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/topic_progress.dart';
import '../services/crash_service.dart';
import 'submission_queue.dart';

/// Konu bazlı ilerleme: çözülen her sorunun konusunu kaydeder ve haritayı
/// besleyen özeti okur.
class ProgressRepository {
  ProgressRepository._();
  static final ProgressRepository instance = ProgressRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Kendi hatanın tekrarını kaydeder ve XP'yi sunucuya yazdırır.
  ///
  /// Eskiden istemci `study_attempts`'e doğrudan satır yazıyordu: ders, konu ve
  /// `correct` tamamen istemci beyanıydı, yani uydurma bir konu haritası
  /// üretmek serbestti. Artık ölçüm satırlarını sunucu, sorunun KENDİ
  /// konusundan yazıyor.
  ///
  /// DÜRÜST SINIR: burada `correct` kaçınılmaz olarak ÖZNEL — kullanıcı kendi
  /// fotoğrafına bakıp kendini notlandırıyor ve sunucu bunu doğrulayamaz.
  /// Kazanç şu: XP artık türetilmiş bir değer ve günlük tavana tabi; sahtelemek
  /// tek bir `update profiles set xp = 999999` yerine binlerce çağrı gerektiriyor.
  ///
  /// Ağ yoksa gönderim KUYRUĞA alınır ve bağlantı gelince uygulanır — yoksa
  /// cevap kaybolur ve bir sonraki açılışta `hydrate()` XP'yi geri alarak
  /// kullanıcıya ilerlemesi silinmiş gibi gösterirdi.
  ///
  /// Dönen değer: sunucudaki güncel toplamlar (kuyruğa alındıysa null).
  Future<Map<String, dynamic>?> submitReview({
    required String mistakeId,
    required bool correct,
    /// Sorunun şıkları varsa işaretlenen şıkkın indeksi.
    ///
    /// Verilirse doğruluğu SUNUCU hesaplar ve [correct] yok sayılır. Seri
    /// çarpanı kullanıcı beyanının değerini beş katına çıkardığı için,
    /// doğrulanabilir yerde doğrulamak şart oldu (bkz. 0041 göçü).
    int? choice,
  }) async {
    // Birikmiş cevaplar varsa önce onlar gitsin (bkz. drainIfPending).
    await submissionQueue.drainIfPending();
    final String token = newSubmissionToken();
    try {
      final dynamic res = await _client.rpc<dynamic>(
        'submit_review',
        params: <String, dynamic>{
          'p_mistake': mistakeId,
          'p_correct': correct,
          'p_choice': choice,
          'p_token': token,
        },
      );
      if (res is List && res.isNotEmpty) {
        return (res.first as Map).cast<String, dynamic>();
      }
      return null;
    } on PostgrestException catch (e) {
      // Sunucu yanıt verdi ve reddetti (ör. kullanıcı bu hatayı silmiş).
      // Kuyruğa almak sonsuz bir yeniden deneme üretirdi.
      debugPrint('tekrar reddedildi, kuyruğa ALINMADI: ${e.code} ${e.message}');
      return null;
    } catch (e, st) {
      debugPrint('tekrar gönderilemedi, kuyruğa alınıyor: $e');
      final bool queued = await submissionQueue.enqueue(<String, dynamic>{
        'kind': 'review',
        'mistake_id': mistakeId,
        'correct': correct,
        'choice': choice,
        'token': token,
      });
      // Kuyruğa DA giremediyse (oturum düşmüş) cevap kayboldu — raporla.
      if (!queued) {
        unawaited(reportError(e, st, context: 'progress.submitReview.lost'));
      }
      return null;
    }
  }

  /// Günlük hedef bonusunu sunucudan ister (günde bir kez, sunucu garantiler).
  Future<Map<String, dynamic>?> claimDailyGoal() async {
    await submissionQueue.drainIfPending();
    try {
      final dynamic res =
          await _client.rpc<dynamic>('claim_daily_goal', params: <String, dynamic>{});
      if (res is List && res.isNotEmpty) {
        return (res.first as Map).cast<String, dynamic>();
      }
      return null;
    } on PostgrestException catch (e) {
      // "bugün hiç çalışılmamış" gibi kalıcı retler kuyruğa girmemeli.
      debugPrint('günlük hedef reddedildi, kuyruğa ALINMADI: ${e.code} ${e.message}');
      return null;
    } catch (e, st) {
      debugPrint('günlük hedef bonusu alınamadı, kuyruğa alınıyor: $e');
      final bool queued =
          await submissionQueue.enqueue(<String, dynamic>{'kind': 'goal'});
      if (!queued) {
        unawaited(reportError(e, st, context: 'progress.claimGoal.lost'));
      }
      return null;
    }
  }

  /// Konu bazlı ilerleme özetim: 'Ders|Konu' → ilerleme.
  Future<Map<String, TopicProgress>> myProgress() async {
    final List<Map<String, dynamic>> rows =
        await _client.from('my_topic_progress').select();
    return <String, TopicProgress>{
      for (final Map<String, dynamic> r in rows)
        '${r['subject']}|${r['concept']}': TopicProgress.fromRow(r),
    };
  }
}

final ProgressRepository progressRepository = ProgressRepository.instance;
