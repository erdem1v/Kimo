import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mistake_repository.dart';
import '../models/received_question.dart';
import '../models/report_reason.dart';
import 'submission_queue.dart';

/// Soru gönderiminin sonucu. "Zaten göndermiştin" ile gerçek hatayı ayırır;
/// aksi halde kullanıcıya sebebi tahmin ettiren bir mesaj gösteriliyordu.
class SendResult {
  const SendResult({
    this.sent = 0,
    this.duplicate = 0,
    this.error,
    this.dailyLimit = false,
    this.notSendable = false,
    this.scanPending = false,
    this.suspended = false,
    this.anonymous = false,
  });

  final int sent;

  /// Gönderilemeyen alıcı sayısı: tekrar yasağı, arkadaş başına tavan,
  /// arkadaş olmama ya da engel. SUNUCU AYRIM YAPMIYOR ve bu bilinçli —
  /// "arkadaş değil" ile "engellendin" ayrımını sızdırmak, deponun
  /// `add_friend_by_code`'daki tek-mesaj ilkesini bozardı.
  final int duplicate;

  final String? error;

  /// Günlük gönderim tavanına çarpıldı (0081). Ayrı tutuluyor çünkü kullanıcıya
  /// söylenecek şey farklı: "yarın tekrar" demek gerekiyor.
  final bool dailyLimit;

  /// Sunucu soruyu gönderilebilir bulmadı (`reason = 'not_sendable'`):
  /// fotoğraf taraması bitmemiş, moderasyon 'ok' değil ya da soru bu
  /// kullanıcıya ait değil.
  ///
  /// [duplicate]DAN AYRI (Task 16 · C0-1). Eskiden ikisi tek sayıda
  /// toplanıyordu ve kullanıcı "yakında göndermiş olabilirsin" mesajını
  /// görüyordu — hiç göndermediği bir soru için, üstelik gerçek sebep
  /// birkaç saniye içinde kendiliğinden geçecekken.
  final bool notSendable;

  /// [notSendable]ın sebebi taramanın SÜRMESİ: beklemek işe yarar.
  final bool scanPending;

  /// GÖNDEREN askıda (`reason = 'suspended'`).
  ///
  /// Task 16'da `not_sendable` ayrıldı ama sunucu DÖRT sebep döndürüyor ve
  /// kalan ikisi hâlâ `blocked`a karışıyordu: askıdaki kullanıcı "Bu soru
  /// onlara gitmedi — yakında göndermiş olabilirsin." görüyordu. Yani C0-1'in
  /// düzeltilen cümlesinin aynısı, bu kez yaptırım yolunda. Askı ekranı
  /// yalnızca açılışta bir kez çıkıyor ve kapatılabiliyor, dolayısıyla
  /// kullanıcı hesabının kısıtlı olduğunu başka hiçbir yerden öğrenmiyordu.
  final bool suspended;

  /// GÖNDEREN anonim (`reason = 'anonymous'`). Kayıt akışın sonunda olduğu
  /// için gerçek bir durum: kaydı atlayan kullanıcı sosyal yüzeye giremiyor.
  final bool anonymous;

  /// `send_question_to_friends` satırını sonuca çevirir.
  ///
  /// AYRI BİR FABRİKA, çünkü kırık olan tam buydu ve sunucu olmadan
  /// sınanamıyordu: Task 16 `not_sendable`ı ayırdı ama `suspended` ve
  /// `anonymous` `blocked`a karışmaya devam etti. Eşleme saf olunca mutasyon
  /// testi onu gerçekten ayırt edebiliyor.
  factory SendResult.fromRow(Map<String, dynamic> row) {
    final String reason = (row['reason'] as String?) ?? '';
    // GÖNDEREN-TARAFI REDLER `blocked` DEĞİL: üçü de "arkadaşın almadı" demek
    // değil, "sen gönderemiyorsun" demek. `duplicate`a yazmak kullanıcıya
    // yanlış hikâyeyi anlatıyordu.
    const Set<String> senderSide = <String>{
      'not_sendable',
      'suspended',
      'anonymous',
    };
    return SendResult(
      sent: (row['sent'] as num?)?.toInt() ?? 0,
      duplicate: senderSide.contains(reason)
          ? 0
          : ((row['blocked'] as num?)?.toInt() ?? 0),
      dailyLimit: reason == 'daily_limit',
      notSendable: reason == 'not_sendable',
      suspended: reason == 'suspended',
      anonymous: reason == 'anonymous',
    );
  }

  bool get ok => sent > 0;

  /// Kullanıcıya gösterilecek mesaj.
  String get message {
    if (sent > 0) {
      final String base = '$sent arkadaşına gönderildi 🚀';
      return duplicate > 0 ? '$base ($duplicate kişiye gitmedi)' : base;
    }
    if (dailyLimit) {
      return 'Bugünün gönderim hakkın doldu. Yarın devam edebilirsin.';
    }
    if (suspended) {
      return 'Hesabın şu an kısıtlı; soru gönderemiyorsun. '
          'Ayrıntısı ve itiraz yolu Ayarlar\'da.';
    }
    if (anonymous) {
      return 'Soru göndermek için önce hesabını açman gerekiyor.';
    }
    if (scanPending) {
      return 'Fotoğrafın kontrolü hâlâ sürüyor. Birkaç saniye sonra tekrar dene.';
    }
    if (notSendable) {
      return 'Bu soru gönderilemiyor: fotoğrafı kontrolden geçmedi.';
    }
    if (duplicate > 0 && error == null) {
      return duplicate == 1
          ? 'Bu soru ona gitmedi — yakında göndermiş olabilirsin.'
          : 'Bu soru onlara gitmedi — yakında göndermiş olabilirsin.';
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

  /// Bir soruyu arkadaşlara gönderir — TEK RPC çağrısı (0081).
  ///
  /// ESKİDEN alıcı başına ayrı INSERT atılıyordu: ortada bir hata olursa
  /// kısmi gönderim kalıyordu ve geri alma yoktu. Ayrıca hiç hız sınırı
  /// yoktu — 0022 unique kısıtı düşürdüğünden beri aynı soru aynı kişiye
  /// sınırsız tekrar gidiyordu ve her INSERT bir push tetikliyordu.
  ///
  /// Sınırlar SUNUCUDA: günlük tavan, arkadaş başına tavan ve "aynı soruyu
  /// 30 gün tekrar gönderme" yasağı `send_question_to_friends` içinde.
  /// Arkadaşlık/engel/askı kontrolü RLS politikasında KALIYOR — istemci
  /// hiçbirini tekrarlamıyor.
  /// `not_sendable` sonrası taramanın bitmesi için beklenecek süreler.
  ///
  /// Ölçüm: üretimde bir fotoğrafın `pending` → `clear` geçişi **2,4 saniye**
  /// sürdü. Merdiven 1+2+3+5 = 11 saniyeye kadar bekliyor ve her adımda önce
  /// taramanın HÂLÂ sürdüğünü doğruluyor — bitmişse ya da damgalanmışsa
  /// beklemek anlamsız, hemen çıkıyor.
  @visibleForTesting
  static List<Duration> scanWaits = const <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
  ];

  /// Bir soruyu arkadaşlara gönderir; tarama sürüyorsa BEKLER.
  ///
  /// **TARAMA YARIŞI (Task 16 · C0-1).** Fotoğraflı bir kayıt eklenince
  /// `mistakes_photo_scan_reset` `photo_scan`i `pending` yapıyor ve tarama
  /// edge fonksiyonu ateşle-unut çağrılıyor. `send_question_to_friends` ise
  /// `photo_scan = 'clear'` istiyor. "Yeni soru çek → doğrudan gönder" yolu
  /// kaydın hemen ardından, AYNI KAREDE gönderiyordu: sunucu `not_sendable`
  /// dönüyor, istemci bunu `blocked` sayıp "yakında göndermiş olabilirsin"
  /// diyor ve gönderim niyeti sessizce kayboluyordu. Üretimde doğrulandı:
  /// soru 00:06:41.022'de yazıldı, tarama 00:06:43.444'te bitti, arada
  /// gönderim düştü ve `question_sends`te satır OLUŞMADI.
  ///
  /// Bekleme BURADA, üç gönderim yolunun da geçtiği tek noktada: çekimden
  /// gönderme, arşivden gönderme ve ortak seri daveti.
  Future<SendResult> sendToFriends({
    required String mistakeId,
    required List<String> receiverIds,
    String? note,
  }) async {
    if (receiverIds.isEmpty) return const SendResult();
    SendResult res = await _sendOnce(
      mistakeId: mistakeId,
      receiverIds: receiverIds,
      note: note,
    );
    if (!res.notSendable) return res;

    for (final Duration wait in scanWaits) {
      if (await mistakeRepository.photoScanOf(mistakeId) != 'pending') break;
      await Future<void>.delayed(wait);
      res = await _sendOnce(
        mistakeId: mistakeId,
        receiverIds: receiverIds,
        note: note,
      );
      if (!res.notSendable) return res;
    }
    // Hâlâ gönderilemiyor: sebebi ayrı söyleniyor. `pending` ise kullanıcı
    // birazdan tekrar deneyebilir; `flagged`/eksik ise deneme boşuna.
    return SendResult(
      notSendable: true,
      scanPending: await mistakeRepository.photoScanOf(mistakeId) == 'pending',
    );
  }

  Future<SendResult> _sendOnce({
    required String mistakeId,
    required List<String> receiverIds,
    String? note,
  }) async {
    try {
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'send_question_to_friends',
        params: <String, dynamic>{
          'p_mistake': mistakeId,
          'p_receivers': receiverIds,
          'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
        },
      );
      if (rows.isEmpty) return const SendResult(error: 'Boş yanıt');
      return SendResult.fromRow(rows.first as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      // 22023 = not çok uzun ya da 20'den fazla alıcı; ikisi de istemcinin
      // zaten engellemesi gereken durumlar, yani buraya düşmesi bir hata.
      //
      // HAM SUNUCU METNİ GÖSTERİLMİYOR: `e.message` SQL hata gövdesi olabilir
      // ve kullanıcıya şema sızdırır. Günlüğe yazılıyor, ekrana sabit bir
      // cümle gidiyor.
      debugPrint('gönderim reddedildi: ${e.code} ${e.message}');
      return const SendResult(error: 'Bağlantı hatası');
    } catch (_) {
      return const SendResult(error: 'Bağlantı hatası');
    }
  }

  /// Gelen kutusunun tek seferde indirdiği en fazla satır.
  ///
  /// LİMİT AÇIKÇA YAZILIYOR (Task 12). Sorgu limitsizdi ama sınırsız değildi:
  /// PostgREST'in `max-rows` ayarı (varsayılan 1000) listeyi SESSİZCE kesiyordu
  /// ve istemci kesildiğini fark edemiyordu. `mistake_repository.dart`
  /// arşivde aynı sorunu Task 08'de çözmüştü; burası atlanmıştı.
  static const int inboxLimit = 200;

  /// Bana gelen sorular (en yeni önce).
  Future<List<ReceivedQuestion>> received({bool onlyUnsolved = false}) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('received_questions')
        .select()
        .order('created_at', ascending: false)
        .limit(inboxLimit);
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
