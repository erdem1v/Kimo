import 'dart:async';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/reviews/domain/review_scheduler.dart';
import '../models/models.dart';
import '../services/crash_service.dart';
import '../state/user_profile.dart';
import 'curriculum_repository.dart';
import 'submission_queue.dart';

/// Hata bankasının Supabase uygulaması: `mistakes` tablosu + `mistake-photos`
/// (özel) storage bucket'ı + `analyze-question` Edge Function (AI Gateway) +
/// aralıklı tekrar planlaması (ReviewScheduler).
class MistakeRepository {
  MistakeRepository._();
  static final MistakeRepository instance = MistakeRepository._();

  static const String _bucket = 'mistake-photos';
  static const ReviewScheduler _scheduler = ReviewScheduler();

  SupabaseClient get _client => Supabase.instance.client;

  /// En yeni [archiveLimit] hata — Hatalarım ekranı için.
  ///
  /// LİMİT AÇIKÇA YAZILIYOR (Task 08). Sorgu eskiden limitsizdi ama sınırsız
  /// değildi: PostgREST'in `max-rows` ayarı (varsayılan 1000) listeyi SESSİZCE
  /// kesiyordu ve istemci kesildiğini fark edemiyordu. Açık bir limit en
  /// azından davranışı okunur kılıyor; ekranın sayaçları zaten `totalCount()`
  /// ile ayrı geliyor, yani "kaç sorum var" doğru kalıyor.
  Future<List<MistakeEntry>> fetch() async {
    final List<Map<String, dynamic>> rows = await _client
        .from('mistakes')
        .select()
        .order('created_at', ascending: false)
        .limit(archiveLimit);
    return _mapRows(rows);
  }

  /// Arşiv ekranının tek seferde indirdiği en fazla satır.
  static const int archiveLimit = 500;

  /// Tek tekrar oturumunda inen en fazla satır.
  ///
  /// Vade sırasına göre EN YAKIN olanlar geliyor, yani kesilen kısım her zaman
  /// "daha az acil" olan. 60, bir oturumda çözülebilecek soru sayısının rahat
  /// üstünde; kalanlar bir sonraki açılışta düşüyor.
  static const int dueLimit = 60;

  // reviewedTodayCount KALDIRILDI (Task 03): hem saat dilimi hatalıydı
  // (yerel saati offset'siz gönderiyordu; gün sınırı 03:00'a kayıyordu) hem
  // satırları indirip uzunluğuna bakıyordu. Sayı artık `my_daily_state`
  // görünümünün `reviewed_today_count` sütunu — Istanbul gününe göre, sunucuda.

  /// Arşivde toplam kaç kayıt var.
  ///
  /// "Bugün" ekranı sıfır-veri hâlini (3c) bununla ayırt ediyor: bugün tekrarı
  /// olmaması ile arşivin hiç açılmamış olması farklı iki durum ve farklı iki
  /// ekran. `head: true` ile satırlar indirilmiyor, yalnızca sayı geliyor.
  Future<int> totalCount() async {
    final PostgrestResponse<dynamic> res = await _client
        .from('mistakes')
        .select('id')
        .count(CountOption.exact);
    return res.count;
  }

  /// Vadesi gelmiş (şimdi ve öncesi), öğrenilmemiş hatalar — pratik için.
  ///
  /// Vade artık ZAMAN damgası (`next_review_at`, 0049): yeni eklenen soru
  /// aynı gün, ~3 saat sonra düşer. Eski istemcilerin kuyruğundan yalnızca
  /// tarih yazılmış satırlar için `next_review_date` yedeği korunuyor.
  ///
  /// **[dueLimit] ile sınırlı (Task 08).** Sorgu eskiden vadesi gelmiş HER
  /// satırı indiriyordu; 800 kaydı olan bir kullanıcıda ekran açılışı yavaşlar
  /// ve bellek şişerdi. Sayaç bu listenin uzunluğundan DEĞİL sunucudaki
  /// `my_daily_state.due_count` alanından okunuyor (bkz. today_screen), yani
  /// limit kullanıcıya yanlış bir sayı göstermiyor.
  Future<List<MistakeEntry>> dueReviews() async {
    final String nowIso = DateTime.now().toUtc().toIso8601String();
    final String today = _dateStr(DateTime.now());
    final List<Map<String, dynamic>> rows = await _client
        .from('mistakes')
        .select()
        .eq('mastered', false)
        .or('next_review_at.lte.$nowIso,'
            'and(next_review_at.is.null,next_review_date.lte.$today)')
        .order('next_review_at', ascending: true, nullsFirst: false)
        .limit(dueLimit);
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
      type: MistakeType.fromDb(row['mistake_type'] as String?),
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
      nextReviewDate: row['next_review_date'] == null
          ? null
          : DateTime.parse(row['next_review_date'] as String),
      nextReviewAt: row['next_review_at'] == null
          ? null
          : DateTime.parse(row['next_review_at'] as String),
      exam: row['exam'] as String?,
      extraConcepts: (row['extra_concepts'] as List<dynamic>?)
              ?.map((dynamic e) => e as String)
              .toList() ??
          const <String>[],
    );
  }

  /// İmzalı URL önbelleği — SON KULLANMA ZAMANIYLA (Task 03, bulgu 10.4).
  ///
  /// Eskiden önbellek hiç yoktu: `MistakePhoto` ListView.builder içinde her
  /// ekrana girişte yeniden kurulduğu için, saniyeler önce imzalanmış bir yol
  /// kaydırma başına yeniden imzalanıyordu — ızgarada onlarca gereksiz istek.
  /// Desen `SocialRepository._avatarUrls` ile birebir aynı; TTL 600 sn SABİT
  /// kalır (moderasyon purge penceresi — aşağıdaki nota bakın), önbellek de o
  /// ömürle birlikte yaşar.
  final Map<String, ({String url, DateTime expiresAt})> _photoUrls =
      <String, ({String url, DateTime expiresAt})>{};

  /// Görsel yüklenemedi (imza öldü / içerik kaldırıldı): bir sonraki istek
  /// taze imza üretsin. [MistakePhoto] yeniden denemeden önce çağırır.
  void invalidateSignedUrl(String path) => _photoUrls.remove(path);

  /// Storage'daki bir fotoğraf için kısa ömürlü imzalı URL üretir (gösterim
  /// anında, tembel; taze imzalar önbellekten). Foto silinmişse null döner.
  Future<String?> signedUrl(String path) async {
    final ({String url, DateTime expiresAt})? cached = _photoUrls[path];
    if (cached != null &&
        DateTime.now().isBefore(
            cached.expiresAt.subtract(const Duration(seconds: 30)))) {
      return cached.url;
    }
    try {
      final String url = await _client.storage
          .from(_bucket)
          .createSignedUrl(path, signedUrlTtlSeconds);
      _photoUrls[path] = (
        url: url,
        expiresAt: DateTime.now()
            .add(const Duration(seconds: signedUrlTtlSeconds)),
      );
      return url;
    } catch (e, st) {
      // Fotoğraf kırık kutu olarak görünür; sebep artık raporda.
      unawaited(reportError(e, st, context: 'mistake.signedUrl'));
      _photoUrls.remove(path);
      return null;
    }
  }

  /// İmzalı fotoğraf adresinin ömrü.
  ///
  /// 1 saatten 10 dakikaya indirildi. Moderasyonla kaldırılan bir içeriğin
  /// dosyası artık siliniyor (bkz. 0031 göçü), ama silme anına kadar dağıtılmış
  /// imzalı adresler ömürleri boyunca çalışmaya devam eder — bu değer o pencere.
  ///
  /// Düşürmenin ön koşulu vardı ve o karşılandı: [MistakePhoto] artık ölmüş bir
  /// imzayı fark edip bir kez yeniden imzalıyor. Bu olmadan TTL'i düşürmek
  /// havuzda kaydırırken görsellerin ölmesine yol açardı.
  static const int signedUrlTtlSeconds = 600;

  /// Bir sorunun fotoğraf tarama durumu: `pending` | `clear` | `flagged`.
  ///
  /// GÖNDERİM YARIŞI İÇİN (Task 16 · C0-1). Fotoğraflı bir kayıt eklenince
  /// `mistakes_photo_scan_reset` tetikleyicisi `photo_scan`i `pending` yapıyor
  /// ve tarama edge fonksiyonu ATEŞLE-UNUT çağrılıyor; ölçülen süre ~2,4
  /// saniye. `send_question_to_friends` ise `photo_scan = 'clear'` istiyor.
  /// Gönderim bu süreyi beklemeden çağrılırsa sunucu `not_sendable` dönüyor.
  ///
  /// `null` = satır okunamadı (ağ ya da yetki); çağıran bunu "bilmiyorum"
  /// sayıp beklemeyi bırakıyor.
  Future<String?> photoScanOf(String id) async {
    try {
      final Map<String, dynamic>? row = await _client
          .from('mistakes')
          .select('photo_scan')
          .eq('id', id)
          .maybeSingle();
      return row?['photo_scan'] as String?;
    } catch (e) {
      debugPrint('tarama durumu okunamadı: $e');
      return null;
    }
  }

  /// Yeni hata ekler; fotoğraf varsa önce Storage'a yükler.
  /// Yeni hata kaydı ekler ve **satırın kimliğini** döndürür.
  ///
  /// KİMLİK NEDEN DÖNÜYOR (Task 12 · P4): Tur 7 · n5'in "yeni soru çek →
  /// doğrudan gönder" yolu kaydedilen sorunun kimliğine ihtiyaç duyuyor.
  /// Alternatif "kaydettikten sonra en yeniyi yeniden çek" olurdu ve o, iki
  /// eşzamanlı kayıtta yanlış soruyu gönderebilirdi.
  ///
  /// `insert(...).select('id').single()` ek bir tur atmıyor: PostgREST aynı
  /// istekte `Prefer: return=representation` ile satırı döndürüyor.
  Future<String?> add({
    required String subject,
    required String concept,
    MistakeType? type,
    required String note,
    Uint8List? imageBytes,
    List<QuestionOption>? options,
    int? correctIndex,
    String? exam,
    List<String> extraConcepts = const <String>[],
  }) async {
    String? path;
    if (imageBytes != null) {
      final String uid = _client.auth.currentUser!.id;
      path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      // `upsert` YOK — VE OLMAMALI (Task 14 · D2).
      //
      // Supabase Storage'da `upsert: true`, `x-upsert` başlığıyla gidiyor ve
      // sunucu bunu INSERT değil UPSERT olarak işliyor: `storage.objects`
      // üzerinde bir UPDATE politikası ARIYOR. Bu depoda storage için yalnızca
      // insert/select/delete politikaları var, dolayısıyla HER yükleme
      //   403 "new row violates row-level security policy"
      // ile düşüyordu. Sonuç: `add()` hiç tamamlanmıyor, çağıran yolu
      // kuyruğa düşüyor ("kuyruğa alınıyor") ve kuruluş akışında
      // `PhotoQueue.flush`in `StorageException` dalı kaydı DÜŞÜRÜP fotoğrafı
      // SİLİYORDU. Kullanıcının gördüğü: "internet var ama fotoğraf kuyrukta
      // kaldı", sonra da yok oldu.
      //
      // Doğru düzeltme burası, UPDATE politikası EKLEMEK DEĞİL: yol zaten
      // milisaniyelik zaman damgası taşıyor (çakışma pratikte imkânsız) ve
      // `mistakes.photo_path` YAZ-BİR-KEZ (0020 `revoke update (photo_path)`).
      // UPDATE politikası eklemek, taraması 'clear' çıkmış bir fotoğrafın
      // üzerine başka bir görsel yazılmasına izin verirdi.
      await _client.storage.from(_bucket).uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
    }

    final Map<String, dynamic> inserted =
        await _client.from('mistakes').insert(<String, dynamic>{
      'subject': subject,
      'concept': concept,
      // İsteğe bağlı: kullanıcı sebep seçmediyse null gider.
      'mistake_type': type?.dbValue,
      'note': note.isEmpty ? null : note,
      'photo_path': path,
      'options': (options == null || options.isEmpty)
          ? null
          : options.map((QuestionOption o) => o.toJson()).toList(),
      'correct_index': correctIndex,
      'exam': (exam == null || exam.isEmpty) ? null : exam,
      // `is_public` GÖNDERİLMİYOR. 0090 sütunun INSERT yetkisini geri aldı
      // (havuz arşivde; açık kalması kullanıcının kendi soru FOTOĞRAFINI
      // hiçbir onay kaydı oluşmadan herkese açabilmesi demekti). Yükte
      // kalmaya devam ettiği için her kayıt 42501 ile reddediliyordu —
      // KAYDETME YOLUNUN TAMAMI kapalıydı, üstelik `photo_queue`un
      // `PostgrestException` dalı reddedilen kaydı düşürüp fotoğrafı da
      // sildiği için sessiz veri kaybına dönüyordu.
      //
      // Sunucu varsayılanı zaten `false` (0007), yani davranış değişmiyor.
      // Havuz v2'de geri açılacaksa yol `lib/_archive/README.md`de yazılı ve
      // ilk adım yetkiyi geri vermek.
      'extra_concepts': extraConcepts.isEmpty ? null : extraConcepts,
    }).select('id').single();
    final String? newId = inserted['id'] as String?;
    // İlk vadeyi (aynı gün +3 saat) ve tarih gölgesini DB tetikleyicisi atar
    // (0049); photo_scan da tetikleyiciyle 'pending' başlar (0050).

    if (path != null) {
      // Hızlı yol: içerik taraması hemen tetiklenir ki paylaşım saniyeler
      // içinde açılsın. BİLİNÇLİ ateşle-unut ve sessiz: başarısız olsa da
      // sunucudaki süpürücü (pg_cron, 10 dk) aynı işi yapar; kullanıcının
      // kayıt akışını ne bekletir ne kirletir.
      unawaited(
        _client.functions
            .invoke('scan-photos', body: const <String, dynamic>{})
            .catchError((Object e) {
          debugPrint('hızlı tarama tetiklenemedi (süpürücü telafi eder): $e');
          return FunctionResponse(status: 0, data: null);
        }),
      );
    }
    return newId;
  }

  /// Bir tekrar sonucunu ([correct]) uygular: planı (adım/tarih/leech/mastered)
  /// ilerletir ve YENİ PLANI DÖNDÜRÜR.
  ///
  /// Dönen [ReviewOutcome] arayüzde "yarın yeniden soracağım" metnini
  /// besliyor; bu yüzden yazma başarısız olsa bile hesaplanan plan dönüyor.
  ///
  /// **Çevrimdışı boşluk kapandı (Task 03):** XP zaten kuyruğa giriyordu ama
  /// takvim yazımı KAYBOLUYORDU — soru eski adımında kalıyor, senkronda
  /// yeniden vadesi gelmiş görünüyor ve doğru cevaplar merdiveni hiç
  /// ilerletmiyordu. Ağ hatasında yazım artık `schedule` türüyle
  /// [SubmissionQueue]'ya giriyor. Yalnızca KUYRUK DA başarısız olursa
  /// (oturum düşmüş) hata fırlar; çağıran bunu kullanıcıya gösteriyor.
  /// Sunucu REDDİ (silinmiş kayıt vb.) kuyruğa alınmaz — tekrar denemek aynı
  /// sonucu verir — ve olduğu gibi fırlatılır.
  ///
  /// [selfReported]: doğruluk kullanıcının BEYANINDAN geliyor (şıksız satırda
  /// "Doğru çözdüm / Bilemedim"). Planlayıcı beyanı daha temkinli işliyor —
  /// bkz. [ReviewScheduler] başlığı.
  Future<ReviewOutcome> submitReview(
    MistakeEntry entry,
    bool correct, {
    bool selfReported = false,
  }) async {
    final ReviewOutcome o = _scheduler.review(
      step: entry.step,
      lapses: entry.lapses,
      correct: correct,
      reviewedOn: DateTime.now(),
      examDate: ReviewScheduler.examCutoffFor(userProfile.examYear),
      selfReported: selfReported,
    );
    final String? id = entry.id;
    if (id == null) return o;
    final Map<String, dynamic> patch = <String, dynamic>{
      'step': o.step,
      'lapses': o.lapses,
      'is_leech': o.isLeech,
      'mastered': o.mastered,
      // Vade artık zaman damgası: UTC geceyarısı = Istanbul 03:00, yani gün
      // aynı kalır. `next_review_date` gölgesini DB tetikleyicisi türetiyor
      // (0049) — iki alanı ayrı ayrı yazıp ayrıştırmıyoruz.
      'next_review_at': DateTime.utc(
        o.nextReviewDate.year,
        o.nextReviewDate.month,
        o.nextReviewDate.day,
      ).toIso8601String(),
      'last_reviewed_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      // Ağ geri geldiyse önce birikmiş kayıtlar gitsin (sıra korunur).
      await submissionQueue.drainIfPending();
      await _client.from('mistakes').update(patch).eq('id', id);
    } on PostgrestException {
      rethrow;
    } catch (_) {
      final bool queued = await submissionQueue.enqueue(<String, dynamic>{
        'kind': 'schedule',
        'mistake_id': id,
        ...patch,
      });
      if (!queued) rethrow;
    }
    return o;
  }

  /// Fotoğrafı AI Gateway (Edge Function) ile değerlendirir: okunabilir bir
  /// soru + şıklar var mı? Geçerliyse şıkları, değilse sebebi döndürür.
  Future<QuestionAnalysis> analyzeQuestion(Uint8List imageBytes) async {
    final FunctionResponse res;
    try {
      res = await _client.functions.invoke(
        'analyze-question',
        body: <String, dynamic>{
          'imageBase64': base64Encode(imageBytes),
          'mimeType': 'image/jpeg',
          'curriculum': userProfile.curriculum,
        },
      );
    } on FunctionException catch (e) {
      // Yaş kapısı (0067): fotoğraf OpenAI'a HİÇ gitmedi. Ağ hatasından
      // ayrılıyor çünkü çıkış yolu farklı — yeniden denemek bağlantıyla değil,
      // yaş adımının tamamlanmasıyla çözülüyor. Kuyruk bu ayrımı kullanıp
      // kaydı düşürmeden bekletiyor.
      final Object? details = e.details;
      final Object? reason =
          details is Map ? details['reason'] : null;
      if (e.status == 403 && reason == 'age_required') {
        return const QuestionAnalysis(
          ok: false,
          options: <QuestionOption>[],
          failure: AnalysisFailure.ageRequired,
        );
      }
      rethrow;
    }
    final dynamic data = res.data;

    // BAYAT AĞAÇ KONTROLÜ (Task 09). Sunucu her yanıtta yürürlükteki taksonomi
    // sürümünü bildiriyor. Elimizdeki farklıysa onay ekranı AÇILMADAN ÖNCE
    // tazeleniyor: yoksa kullanıcı listede olmayan bir konu seçer ve
    // kaydederken `KM022` alır — sebebini anlamadığı bir hata.
    //
    // Sürüm aynıysa çağrı yapılmıyor; farklıysa tek bir RPC turu.
    if (data is Map) {
      await curriculumRepository.refreshIfStale(
        userProfile.curriculum,
        data['taxonomy_version'] as String?,
      );
    }

    if (data is! Map) {
      return const QuestionAnalysis(
          ok: false,
          options: <QuestionOption>[],
          failure: AnalysisFailure.unknown);
    }

    // Günlük hak bitti: sunucu OpenAI'ya HİÇ GİTMEDİ ve 200 ile bunu söyledi.
    // Hata değil, ürün durumu — çağıran elle giriş formunu açıyor.
    if (data['allowed'] == false) {
      // `resets_at` OKUNMUYOR: sunucu o alanı 0075'te BİLEREK kaldırdı
      // ("`resets_at` GİTTİ") ve `creditFields()` onu hiç göndermiyor.
      // İstemci kaldırılmış bir alanı okumaya devam ediyordu ve sonuç hiçbir
      // widget tarafından da kullanılmıyordu — sessiz ölü kod, ama sonraki
      // okuyucuyu "sunucu bunu gönderiyor" diye yanıltıyordu.
      return const QuestionAnalysis.outOfCredit();
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

    // Kalan hak HER YANITTA geliyor. Eskiden yalnızca `ok` dalında parse
    // ediliyordu, yani başarısız analizden sonra arayüzdeki sayı eski kalıyor
    // ve kullanıcı harcadığı hakkı göremiyordu.
    //
    // TASK 12: okunamayan fotoğrafta hak artık HARCANMIYOR — sunucu iade
    // ediyor (0083) ve `refunded` ile söylüyor. `remaining` de iade
    // SONRASININ değeri, yani ikisi tutarlı.
    final int? remaining = (data['remaining'] as num?)?.toInt();
    final bool refunded = data['refunded'] == true;

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
        creditRemaining: remaining,
        refunded: refunded,
      );
    }

    // Sunucu enum kod döndürüyor (serbest metin değil). Kod yoksa ya da
    // bayraklarla çelişiyorsa bayraklardan türet — eski istemcinin sunucuya
    // karşı çalışabilmesi için de gerekli.
    AnalysisFailure? failure =
        AnalysisFailure.fromCode(data['reason_code'] as String?);
    if (failure == null || failure == AnalysisFailure.unknown) {
      failure = !readable
          ? AnalysisFailure.unreadable
          : !hasQuestion
              ? AnalysisFailure.noQuestion
              : AnalysisFailure.noOptions;
    }
    return QuestionAnalysis(
        ok: false,
        options: <QuestionOption>[],
        failure: failure,
        creditRemaining: remaining,
        refunded: refunded);
  }

  /// Sunucunun "konu ağaçta yok" hatası (göç 0071).
  ///
  /// İstemcinin ağacı bayatladığında görülüyor. Çağıran bunu yakalayıp ağacı
  /// tazeliyor ve kullanıcıya konuyu yeniden seçmesini söylüyor.
  static const String staleTopicCode = 'KM022';

  /// Tek bir soruyu KALICI olarak siler: satır ve depodaki fotoğraf birlikte.
  ///
  /// Kullanıcının arşivinden bir soruyu çıkarmasının tek yolu bugüne kadar
  /// TÜM HESABI silmekti (A-9). Yanlış eklenen ya da özel bilgi içeren bir
  /// fotoğraf için makul bir yol olması gerekiyordu.
  ///
  /// NEDEN EDGE FUNCTION: silme iki nesneye dokunuyor. İstemci satırı
  /// silseydi `photo_path`i kaybeder ve dosya yetim kalırdı; SQL'den
  /// `storage.objects` silmek de yetmez (metadata gider, nesne kalır — 0031'in
  /// dersi). `delete-question` sahipliği doğruluyor, önce nesneyi sonra satırı
  /// siliyor. İstemcinin doğrudan DELETE yetkisi 0069'da geri alındı.
  Future<void> deleteMistake(String id) async {
    await _client.functions.invoke(
      'delete-question',
      body: <String, dynamic>{'mistakeId': id},
    );
  }

  /// Eksik bir eski satırı tamamlar: şık etiketleri + doğru şık.
  ///
  /// Yeni kayıtlar hep eksiksiz (`ConfirmMistakeScreen` şıksız kaydetmiyor);
  /// bu yol yalnızca o kural konmadan önce yazılmış satırlar için. İki sütun
  /// da `authenticated`'ın UPDATE listesinde (0069), yani RPC gerekmiyor.
  Future<void> completeMistake(
    String id, {
    required List<QuestionOption> options,
    required int correctIndex,
  }) async {
    await _client.from('mistakes').update(<String, dynamic>{
      'options': options.map((QuestionOption o) => o.toJson()).toList(),
      'correct_index': correctIndex,
    }).eq('id', id);
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final MistakeRepository mistakeRepository = MistakeRepository.instance;
