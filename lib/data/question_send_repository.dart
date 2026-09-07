import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/received_question.dart';
import '../models/report_reason.dart';
import 'submission_queue.dart';

/// Soru gönderiminin sonucu. "Zaten göndermiştin" ile gerçek hatayı ayırır;
/// aksi halde kullanıcıya sebebi tahmin ettiren bir mesaj gösteriliyordu.
class SendResult {
  const SendResult({this.sent = 0, this.duplicate = 0, this.error});

  final int sent;
  final int duplicate;
  final String? error;

  bool get ok => sent > 0;

  /// Kullanıcıya gösterilecek mesaj.
  String get message {
    if (sent > 0) {
      final String base = '$sent arkadaşına gönderildi 🚀';
      return duplicate > 0 ? '$base ($duplicate kişide zaten vardı)' : base;
    }
    if (duplicate > 0 && error == null) {
      return duplicate == 1
          ? 'Bu soruyu ona zaten göndermiştin.'
          : 'Bu soruyu onlara zaten göndermiştin.';
    }
    return 'Gönderilemedi: ${error ?? 'bilinmeyen hata'}';
  }
}

/// Arkadaşa birebir soru gönderme: gönderim, gelen kutusu, cevaplama ve
/// şikâyet.
///
/// Soru HAVUZU bu sürümde yok ve bu dosyada da yok — havuz yolları
/// `lib/_archive/pool/pool_repository.dart` altına taşındı. İkisi aynı dosyada
/// durduğu için "havuz kalkınca gönderim de kalkar" sanılıyordu; ayrıldılar.
class QuestionSendRepository {
  QuestionSendRepository._();
  static final QuestionSendRepository instance = QuestionSendRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Bir soruyu arkadaşlara gönderir. Arkadaşlık kontrolü RLS'te zorunludur.
  /// Aynı soru aynı kişiye tekrar gönderilebilir (bkz. 0022 göçü).
  Future<SendResult> sendToFriends({
    required String mistakeId,
    required List<String> receiverIds,
    String? note,
  }) async {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) {
      return const SendResult(error: 'Oturum yok');
    }
    if (receiverIds.isEmpty) return const SendResult();
    int sent = 0;
    int duplicate = 0;
    String? error;
    for (final String receiver in receiverIds) {
      try {
        await _client.from('question_sends').insert(<String, dynamic>{
          'sender_id': uid,
          'receiver_id': receiver,
          'mistake_id': mistakeId,
          'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
        });
        sent++;
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          // 0022 göçü çalıştırılmamış eski veritabanlarında hâlâ olabilir.
          duplicate++;
        } else if (e.code == '42501') {
          error ??= 'Arkadaşlık onaylı değil';
        } else {
          error ??= e.message;
        }
      } catch (_) {
        error ??= 'Bağlantı hatası';
      }
    }
    return SendResult(sent: sent, duplicate: duplicate, error: error);
  }

  /// Bana gelen sorular (en yeni önce).
  Future<List<ReceivedQuestion>> received({bool onlyUnsolved = false}) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('received_questions')
        .select()
        .order('created_at', ascending: false);
    final List<ReceivedQuestion> items = rows
        .map(ReceivedQuestion.fromRow)
        .toList();
    if (!onlyUnsolved) return items;
    return items.where((ReceivedQuestion q) => !q.solved).toList();
  }

  // unsolvedCount KALDIRILDI (Task 03): tek bir tam sayı için satır
  // indiriyordu. Sayı artık `my_daily_state.unsolved_received_count` —
  // gelen kutusuyla aynı süzgeçlerle (moderasyon/engel/kaldırma) sunucuda.

  /// Arkadaştan gelen soruyu cevaplar.
  ///
  /// Doğruluk SUNUCUDA belirlenir; istemci yalnızca hangi şıkkı işaretlediğini
  /// söyler ve doğru şıkkı ancak yanıtla öğrenir.
  ///
  /// Ağ yoksa cevap KUYRUĞA alınır ve `queued` sonucu döner; kaybolmaz.
  /// Tekrar gönderim güvenli — sunucu XP'yi yalnızca ilk çözümde veriyor
  /// (`solved_at is null`).
  Future<AnswerResult> answerSentQuestion(String sendId, int choice) async {
    // Ağ geri gelmişse birikmiş cevapları önce gönder; böylece aşağıdaki
    // yanıttaki toplamlar en güncel durumu yansıtır.
    await submissionQueue.drainIfPending();
    try {
      final dynamic res = await _client.rpc<dynamic>(
        'submit_sent_answer',
        params: <String, dynamic>{'p_send': sendId, 'p_choice': choice},
      );
      return AnswerResult.fromRpc(res);
    } on PostgrestException {
      rethrow; // sunucu reddetti; tekrar denemek aynı sonucu verir
    } catch (_) {
      final bool queued = await submissionQueue.enqueue(<String, dynamic>{
        'kind': 'sent',
        'send_id': sendId,
        'choice': choice,
      });
      // Kuyruğa alınamadıysa (oturum düşmüş) cevap KAYBOLDU; kullanıcıya
      // "kaydedildi" demek yanlış olurdu.
      if (!queued) rethrow;
      return const AnswerResult.queued();
    }
  }

  /// Gelen bir soruyu şikâyet eder. Şikâyet edilen içerik moderasyon kuyruğuna
  /// düşer ve şikâyet edene bir daha gösterilmez.
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

  /// Gelen bir soruyu kutudan kaldırır (3n'deki "Sil").
  ///
  /// Satır SİLİNMİYOR, yalnızca alıcı için gizleniyor: gönderenin kaydı ve —
  /// şikâyet edilmişse — moderasyon izi duruyor. Gerçekten silmek, rahatsız
  /// edici bir gönderimi incelenemez kılardı (bkz. 0051 göçü).
  ///
  /// Hata YUTULMUYOR: çağıran yakalayıp kullanıcıya gösteriyor. Yerel olarak
  /// gizleyip sunucuya yazamamak, uygulama yeniden açıldığında sorunun geri
  /// gelmesi demek olurdu.
  Future<void> dismissReceived(String sendId) async {
    await _client.rpc<void>(
      'dismiss_received_question',
      params: <String, dynamic>{'p_send': sendId},
    );
  }
}

/// Bir cevabın sunucudan dönen sonucu.
class AnswerResult {
  const AnswerResult({
    required this.correct,
    this.correctIndex,
    this.totals,
    this.combo = 0,
    this.multiplier = 1,
  }) : queued = false;

  /// Ağ yoktu: cevap kuyruğa alındı, sonuç henüz bilinmiyor.
  ///
  /// Doğruluğu sunucu belirlediği için çevrimdışıyken sonucu gösteremiyoruz.
  /// Gösterilemez olması cevabın KAYBOLDUĞU anlamına gelmiyor — bağlantı
  /// gelince kuyruk uygular ve toplamlar düzelir.
  const AnswerResult.queued()
    : correct = false,
      correctIndex = null,
      totals = null,
      combo = 0,
      multiplier = 1,
      queued = true;

  /// Cevap doğru muydu (sunucu belirledi). [queued] ise anlamsızdır.
  final bool correct;

  /// Ağ hatası yüzünden kuyruğa alındı mı?
  final bool queued;

  /// Doğru şıkkın indeksi — yalnızca cevap verildikten SONRA öğreniliyor.
  final int? correctIndex;

  /// Sunucudaki güncel xp / weekly_xp / streak / league.
  final Map<String, dynamic>? totals;

  /// Bu cevaptan sonraki ardışık doğru sayısı (sunucu hesaplıyor).
  ///
  /// Oturumun EN UZUN kombosu istemcide bu değerin maksimumu alınarak
  /// türetiliyor; sunucuda ayrı bir alan yok.
  final int combo;

  /// Bu cevaba uygulanan XP çarpanı. Arayüzde gösterilen çarpan BUDUR —
  /// gösterilenle verilen ayrışmasın diye sunucudan geliyor.
  final int multiplier;

  factory AnswerResult.fromRpc(dynamic res) {
    final Map<String, dynamic> row = res is List && res.isNotEmpty
        ? (res.first as Map).cast<String, dynamic>()
        : (res is Map ? res.cast<String, dynamic>() : <String, dynamic>{});
    return AnswerResult(
      correct: (row['correct'] as bool?) ?? false,
      correctIndex: (row['correct_index'] as num?)?.toInt(),
      totals: row.isEmpty ? null : row,
      combo: (row['combo'] as num?)?.toInt() ?? 0,
      multiplier: (row['multiplier'] as num?)?.toInt() ?? 1,
    );
  }
}

final QuestionSendRepository questionSendRepository =
    QuestionSendRepository.instance;
