import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/crash_service.dart';
import '../state/user_profile.dart';
import 'mistake_repository.dart';
import 'submission_queue.dart';

/// Bekleyen bir fotoğrafın hangi işi beklediği.
enum PhotoQueueState {
  /// Analiz beklemede: bağlantı yok ya da yaş adımı henüz tamamlanmadı.
  needsAnalysis,

  /// Analiz bitti (ya da hiç yapılamayacak) ama zorunlu alan eksik —
  /// kullanıcının doğru şıkkı işaretlemesi gerekiyor.
  needsUser,

  /// Her şey dolu; yalnızca yükleme + insert kaldı.
  ready;

  static PhotoQueueState fromDb(String? v) => switch (v) {
        'needsAnalysis' => PhotoQueueState.needsAnalysis,
        'ready' => PhotoQueueState.ready,
        _ => PhotoQueueState.needsUser,
      };

  String get dbValue => name;
}

/// [PhotoQueue.enqueue] sonucu. Sessiz başarısızlık YOK: çağıran her durumda
/// kullanıcıya ne olduğunu söyleyebilmeli.
enum PhotoQueueAdd {
  ok,

  /// Kuyruk dolu (kayıt sayısı ya da toplam boyut). Kullanıcıya bekleyenler
  /// ekranına giden bir çıkış yolu gösterilmeli — yoksa sıkışır.
  full,

  /// Oturum yok (jeton düştü): kayıt kimin adına yazılacağı bilinmiyor.
  noSession,

  /// Bayt diske yazılamadı (yer yok, izin yok).
  diskError,
}

/// Kuyruktaki tek kayıt — arayüz için yazılmış görünüm.
class PendingPhoto {
  const PendingPhoto({
    required this.id,
    required this.state,
    required this.createdAt,
    required this.gatedByAge,
    this.subject,
    this.concept,
    this.batchId,
  });

  final String id;
  final PhotoQueueState state;
  final DateTime createdAt;

  /// Yaş adımı tamamlanana kadar hiçbir şey yapılmayacak (onboarding çekimi).
  final bool gatedByAge;

  final String? subject;
  final String? concept;

  /// Aynı partide çekilen kareler aynı damgayı taşıyor; parti sonuç ekranı
  /// bunu kullanıyor. `null` = tek kare (bugünkü yol).
  final String? batchId;
}

/// Soru fotoğrafları için KALICI kuyruk.
///
/// NEDEN VAR: cevaplar için kuyruk vardı (bkz. [SubmissionQueue]) ama fotoğraf
/// çekmek için yoktu — bağlantı yokken öğrenci soru EKLEYEMİYORDU. Hedef kitle
/// serviste, okul koridorunda ve kapsama alanı zayıf yerlerde çalışıyor.
///
/// İKİNCİ İŞ: aynı mekanizma yaş kapısını da çözüyor (A-2). Onboarding'de
/// fotoğraf yaş adımından ÖNCE çekiliyor; artık yerelde bekliyor ve analiz
/// ancak yaş doğrulandıktan sonra çalışıyor. 13 altı reddedilirse
/// [purgeAgeGated] kaydı ve dosyayı siliyor — fotoğraf hiçbir yere gitmemiş
/// oluyor.
///
/// [SubmissionQueue] DESENİNİ İZLİYOR: tekil sınıf, `uid` damgası, sıra
/// korumalı `flush`, `PostgrestException` → kaydı düşür / ağ hatası → dur
/// ayrımı, `_flushing` kilidi, aynı üç tetikleyici (uygulama öne gelince,
/// soğuk açılış, gönderim öncesi [drainIfPending]).
///
/// ÜÇ BİLİNÇLİ FARK:
///
/// 1. **Baytlar prefs'te DEĞİL, dosyada.** Bir JPEG'i base64'e çevirip
///    `SharedPreferences`'a yazmak megabaytlarca metin demek ve prefs her
///    yazımda dosyanın tamamını yeniden serileştiriyor. Üstveri prefs'te,
///    baytlar `<belgeler>/photo_queue/<id>.jpg` dosyasında.
///
/// 2. **Sınır aşımında en eski DÜŞÜRÜLMEZ, yeni kayıt REDDEDİLİR.**
///    [SubmissionQueue] en eskiyi düşürüyor çünkü orada kaybolan şey tekrar
///    üretilebilir bir eylem. Burada kaybolan şey kullanıcının fotoğrafı;
///    sessizce silmek kabul edilemez.
///
/// 3. **Sıra katı DEĞİL.** `needsUser` durumundaki bir kayıt kullanıcı eylemi
///    bekliyor; onu beklemek arkasındaki bütün fotoğrafları rehin alırdı —
///    [SubmissionQueue]'nun kalıcı-ret dalını yazdıran hatanın aynısı.
///    Atlanıyor, sırası korunuyor.
///
/// Semantik: **en az bir kez**. Yükleme yolu (`MistakeRepository.add`)
/// idempotent DEĞİL — aynı kayıt iki kez giderse iki satır oluşur. Bu yüzden
/// kayıt, `add` DÖNDÜKTEN sonra ve yalnızca bir kez siliniyor; yanıt
/// kaybolursa (nadir) kopya oluşabilir, kullanıcı bunu silebilir. Alternatif
/// bir sunucu-tarafı idempotans anahtarı `mistakes`e yeni bir sütun ve yeni
/// bir lockdown göçü isterdi; dört kişilik iç testte bu takas doğru değil.
class PhotoQueue {
  PhotoQueue._();
  static final PhotoQueue instance = PhotoQueue._();

  static const String _storageKey = 'pending_photos_v1';
  static const String _dirName = 'photo_queue';

  /// En fazla kaç fotoğraf bekleyebilir.
  static const int maxEntries = 20;

  /// Kuyruğun diskte kaplayabileceği en fazla yer.
  static const int maxTotalBytes = 30 * 1024 * 1024;

  /// Tek partide en fazla kaç fotoğraf (Tur 7 · n4: "Tek seferde 10 fotoğraf").
  static const int batchMax = 10;

  /// Düşük bellekli cihazlarda inilen sınır.
  static const int batchMaxLowMemory = 3;

  /// Cihazın belleğine göre parti sınırı.
  ///
  /// EMSAL: Microsoft Lens tek taramada 100 görsele izin veriyor ama Android'de
  /// bunu "3 GB'dan fazla RAM" koşuluna bağlıyor — RAM'e bağlı kademeli limit
  /// yerleşik bir desen.
  ///
  /// AMA ASIL KORUMA BU DEĞİL: baytlar hiçbir zaman bellekte TUTULMUYOR
  /// (diske yazılıyor, bellekte yalnızca ~160px küçük resim kalıyor), yani
  /// 10 kare ≈ 1 MB küçük resim demek — tam boyutlu dekodun ürettiği ~190 MB
  /// değil. Kademe ikinci savunma.
  ///
  /// [memoryMb] `null` iken TAM SINIR dönüyor ve bu bilinçli: bellek sinyali
  /// henüz bağlanmadı (`device_info_plus` bağımlılığı gerekiyor). Sinyalsiz
  /// durumda sınırı düşürmek, cihazların büyük bölümünü sebepsiz
  /// cezalandırırdı — disk deseni zaten devrede.
  static int batchLimitFor(int? memoryMb) {
    if (memoryMb == null) return batchMax;
    return memoryMb <= 3072 ? batchMaxLowMemory : batchMax;
  }

  /// Partiden ÖNCE sorulan soru: kuyrukta [count] kayıt için yer var mı?
  ///
  /// NEDEN ÖNDEN: kuyruk 20 kayıt / 30 MB ve iki parti onu TAM DOLDURUYOR.
  /// Önden sormayınca kullanıcı 10 kare çekiyor, sonra [enqueue] bir kısmını
  /// [PhotoQueueAdd.full] ile reddediyor ve hangi karenin kaybolduğunu
  /// anlamıyor. Şimdi akış hiç başlamıyor ve bekleyenler ekranına çıkış
  /// gösteriliyor.
  Future<int> freeSlots() async {
    final List<Map<String, dynamic>> items = await _load();
    return (maxEntries - items.length).clamp(0, maxEntries);
  }

  SupabaseClient get _client => Supabase.instance.client;

  List<Map<String, dynamic>>? _cache;
  bool _flushing = false;

  /// Testlerde `path_provider` eklentisi yok; dizin buradan verilebiliyor.
  @visibleForTesting
  static Directory? directoryOverride;

  // --------------------------------------------------------- test dikişleri
  //
  // NEDEN SAHTE SUPABASE İSTEMCİSİ DEĞİL: `flush()`in sınanması gereken yanı
  // ağ katmanı değil, KARAR AĞACI — sıranın korunması, `needsUser`ın
  // atlanması, hangi hatada kaydın düşürülüp hangisinde beklendiği. Bunun için
  // ağın kendisini taklit etmek gerekmiyor; ağa giden ÜÇ çağrıyı dışarıdan
  // vermek yetiyor. `directoryOverride` deseninin aynısı ve yeni bağımlılık
  // getirmiyor (`mocktail` hâlâ eklenmedi).
  //
  // Üretimde hepsi `null` ve gerçek tekiller çağrılıyor; bir sızıntı olsaydı
  // `debugResetSeams` çağrılmadığı için testler arasında da görünürdü.

  @visibleForTesting
  static Future<QuestionAnalysis> Function(Uint8List bytes)? analyzeOverride;

  @visibleForTesting
  static Future<void> Function(Map<String, dynamic> entry, Uint8List bytes)?
      uploadOverride;

  @visibleForTesting
  static bool Function()? aiConsentOverride;

  /// Oturum kimliği. Test ortamında `Supabase.instance` kurulu DEĞİL ve ona
  /// dokunmak fırlatıyor; bu dikiş olmadan `flush()` hiç sınanamıyordu.
  @visibleForTesting
  static String? uidOverride;

  /// Testler arası sızıntıyı kapatır. Üretimde çağıran yok.
  @visibleForTesting
  static void debugResetSeams() {
    analyzeOverride = null;
    uploadOverride = null;
    aiConsentOverride = null;
    uidOverride = null;
  }

  /// Oturumdaki kullanıcı. Dikiş verilmişse `Supabase.instance`e HİÇ
  /// dokunmuyor — test ortamında o erişimin kendisi fırlatıyor.
  String? _uid() => uidOverride ?? _client.auth.currentUser?.id;

  /// Testlerde bellek önbelleğini boşaltır.
  ///
  /// Sınıf bir TEKİL: iki test arasında `SharedPreferences` sahte değerleri
  /// değişse bile `_cache` eski listeyi tutar ve ikinci test birincinin
  /// verisini görür. Üretimde çağıran yok.
  @visibleForTesting
  void debugResetCache() => _cache = null;

  Future<Directory> _dir() async {
    final Directory? override = directoryOverride;
    final Directory base =
        override ?? Directory('${(await getApplicationDocumentsDirectory()).path}/$_dirName');
    if (!base.existsSync()) base.createSync(recursive: true);
    return base;
  }

  Future<File> _fileFor(String id) async => File('${(await _dir()).path}/$id.jpg');

  // ------------------------------------------------------------------ disk
  Future<List<Map<String, dynamic>>> _load() async {
    final List<Map<String, dynamic>>? cached = _cache;
    if (cached != null) return cached;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        return _cache = <Map<String, dynamic>>[];
      }
      final dynamic decoded = jsonDecode(raw);
      return _cache = <Map<String, dynamic>>[
        if (decoded is List)
          for (final dynamic e in decoded)
            if (e is Map) e.cast<String, dynamic>(),
      ];
    } catch (e) {
      // Bozuk kayıt kuyruğu kalıcı olarak kilitlemesin ([SubmissionQueue] ile
      // aynı gerekçe). Üstveri kaybolduğu için diskteki dosyaların artık
      // sahibi yok; [_pruneOrphans] onları topluyor — yoksa 30 MB kapısına
      // SAYILMAYAN, sonsuza dek büyüyen bir sızıntı kalıyordu.
      debugPrint('fotoğraf kuyruğu okunamadı: $e');
      _cache = <Map<String, dynamic>>[];
      unawaited(_pruneOrphans());
      return _cache!;
    }
  }

  Future<void> _persist(List<Map<String, dynamic>> items) async {
    _cache = items;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(items));
    } catch (e) {
      debugPrint('fotoğraf kuyruğu yazılamadı: $e');
    }
  }

  /// Üstverisi olmayan `.jpg` dosyalarını siler.
  ///
  /// NEDEN VAR: `photo_queue.dart` bu fonksiyonu AYLARDIR çağırıyormuş gibi
  /// yazıyordu ama depoda TANIMI YOKTU (tek geçiş bir yorum satırıydı). Sonucu
  /// şuydu: bozuk bir prefs JSON'u ya da kaybolan bir üstveri, diskteki
  /// fotoğrafları sahipsiz bırakıyordu ve toplam boyut prefs'teki `bytes`
  /// alanlarından hesaplandığı için o dosyalar [maxTotalBytes] kapısına
  /// DAHİL BİLE OLMUYORDU — yani sınırsız bir disk sızıntısı.
  ///
  /// [_graceMs] NEDEN VAR: [enqueue] önce dosyayı yazıyor, SONRA üstveriyi
  /// kalıcılaştırıyor. Bu iki adımın arasında koşan bir budama, geçerli bir
  /// fotoğrafı siler. Taze dosyalara dokunmamak o yarışı kapatıyor; yetim
  /// gerçekten yetimse bir sonraki turda toplanıyor.
  Future<void> _pruneOrphans() async {
    const int graceMs = 60 * 1000;
    try {
      final Directory base = await _dir();
      if (!base.existsSync()) return;
      final Set<String> known = <String>{
        for (final Map<String, dynamic> e in await _load())
          if (e['id'] is String) '${e['id']}.jpg',
      };
      final DateTime now = DateTime.now();
      int removed = 0;
      for (final FileSystemEntity f in base.listSync()) {
        if (f is! File) continue;
        final String name = f.path.split(Platform.pathSeparator).last;
        if (!name.endsWith('.jpg') || known.contains(name)) continue;
        if (now.difference(f.statSync().modified).inMilliseconds < graceMs) {
          continue;
        }
        f.deleteSync();
        removed++;
      }
      if (removed > 0) debugPrint('kuyruk: $removed yetim dosya silindi');
    } catch (e) {
      // Budama bir KOLAYLIK; başarısız olması kuyruğu durdurmamalı.
      debugPrint('yetim dosyalar budanamadı: $e');
    }
  }

  Future<void> _deleteFile(String id) async {
    try {
      final File f = await _fileFor(id);
      if (f.existsSync()) f.deleteSync();
    } catch (e) {
      debugPrint('kuyruk dosyası silinemedi ($id): $e');
    }
  }

  Future<int> _totalBytes(List<Map<String, dynamic>> items) async {
    int total = 0;
    for (final Map<String, dynamic> e in items) {
      final Object? n = e['bytes'];
      if (n is num) total += n.toInt();
    }
    return total;
  }

  // --------------------------------------------------------------- yazma
  /// Fotoğrafı kuyruğa alır.
  ///
  /// [fields] `ConfirmMistakeScreen`'in topladığı alanlar; boş da olabilir
  /// (onboarding çekiminde form hiç açılmıyor). [gatedByAge] true ise kayıt
  /// yaş adımı tamamlanana kadar HİÇ işlenmez.
  Future<PhotoQueueAdd> enqueue({
    required Uint8List bytes,
    required PhotoQueueState state,
    bool gatedByAge = false,
    Map<String, dynamic> fields = const <String, dynamic>{},
    String? batchId,
  }) async {
    final String? uid = _uid();
    if (uid == null) {
      debugPrint('oturum yok: fotoğraf kuyruğa ALINAMADI');
      return PhotoQueueAdd.noSession;
    }

    final List<Map<String, dynamic>> items = await _load();
    if (items.length >= maxEntries ||
        (await _totalBytes(items)) + bytes.length > maxTotalBytes) {
      return PhotoQueueAdd.full;
    }

    final String id = newSubmissionToken();
    try {
      final File f = await _fileFor(id);
      f.writeAsBytesSync(bytes);
    } catch (e) {
      debugPrint('kuyruk dosyası yazılamadı: $e');
      return PhotoQueueAdd.diskError;
    }

    items.add(<String, dynamic>{
      ...fields,
      'id': id,
      'uid': uid,
      'bytes': bytes.length,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'state': state.dbValue,
      'gate': gatedByAge ? 'age' : null,
      // PARTİ DAMGASI ÜSTVERİDE, ŞEMADA DEĞİL (Tur 7 · n4). Parti bir
      // istemci kavramı: sunucu tarafında 10 kare, 10 bağımsız `mistakes`
      // satırı — "bir soruya çok fotoğraf" DEĞİL, "arka arkaya çok soru".
      // Bu yüzden yeni tablo, yeni sütun ve yeni lockdown göçü gerekmiyor.
      'batch': batchId,
    });
    await _persist(items);
    return PhotoQueueAdd.ok;
  }

  /// Kullanıcı formu tamamlayınca çağrılır: alanları yazar ve durumu yeniden
  /// hesaplar (eksiksizse `ready`).
  Future<void> update(String id, Map<String, dynamic> fields) async {
    final List<Map<String, dynamic>> items = await _load();
    for (final Map<String, dynamic> e in items) {
      if (e['id'] != id) continue;
      e.addAll(fields);
      e['state'] = _isComplete(e)
          ? PhotoQueueState.ready.dbValue
          : PhotoQueueState.needsUser.dbValue;
      // Yaş kilidi kullanıcı eylemiyle KALKMAZ; onu yalnızca yaş adımı açar.
      break;
    }
    await _persist(items);
  }

  /// Kaydı ve dosyasını siler (kullanıcı vazgeçti ya da gönderildi).
  Future<void> remove(String id) async {
    final List<Map<String, dynamic>> items = await _load();
    items.removeWhere((Map<String, dynamic> e) => e['id'] == id);
    await _persist(items);
    await _deleteFile(id);
  }

  /// 13 yaş sınırı reddettiğinde: yaş kapısında bekleyen ne varsa gider.
  ///
  /// Fotoğraf hiç yüklenmediği ve hiç analiz edilmediği için depoda ya da
  /// OpenAI'da bırakılacak bir şey yok — silinen tek kopya cihazdaki.
  Future<void> purgeAgeGated() async {
    final List<Map<String, dynamic>> items = await _load();
    final List<String> ids = <String>[
      for (final Map<String, dynamic> e in items)
        if (e['gate'] == 'age') e['id'] as String,
    ];
    if (ids.isEmpty) return;
    items.removeWhere((Map<String, dynamic> e) => e['gate'] == 'age');
    await _persist(items);
    for (final String id in ids) {
      await _deleteFile(id);
    }
    debugPrint('yaş kapısı reddi: ${ids.length} bekleyen fotoğraf silindi');
  }

  /// Yaş adımı geçildi: kilit kalkıyor ve kayıtlar işlenebilir hâle geliyor.
  Future<void> releaseAgeGate() async {
    final List<Map<String, dynamic>> items = await _load();
    bool changed = false;
    for (final Map<String, dynamic> e in items) {
      if (e['gate'] == 'age') {
        e['gate'] = null;
        changed = true;
      }
    }
    if (changed) await _persist(items);
  }

  /// Oturum kapanınca: bekleyen kayıtlar ve dosyaları diskte kalmasın.
  Future<void> clear() async {
    final List<Map<String, dynamic>> items = await _load();
    final List<String> ids = <String>[
      for (final Map<String, dynamic> e in items) e['id'] as String,
    ];
    // Nesneyi DEĞİŞTİRMİYORUZ, içeriğini boşaltıyoruz ([SubmissionQueue] ile
    // aynı gerekçe: devam eden bir flush aynı listeyi tutuyor olabilir).
    items.clear();
    await _persist(items);
    for (final String id in ids) {
      await _deleteFile(id);
    }
  }

  // --------------------------------------------------------------- okuma
  Future<int> loadPendingCount() async => (await _load()).length;

  /// Kullanıcı eylemi bekleyen kayıt sayısı (şerit metnini bu ayırıyor).
  Future<int> loadNeedsUserCount() async => (await _load())
      .where((Map<String, dynamic> e) =>
          e['state'] == PhotoQueueState.needsUser.dbValue)
      .length;

  Future<List<PendingPhoto>> list() async {
    final List<Map<String, dynamic>> items = await _load();
    return <PendingPhoto>[
      for (final Map<String, dynamic> e in items)
        PendingPhoto(
          id: e['id'] as String,
          state: PhotoQueueState.fromDb(e['state'] as String?),
          createdAt:
              DateTime.tryParse(e['created_at'] as String? ?? '')?.toLocal() ??
                  DateTime.now(),
          gatedByAge: e['gate'] == 'age',
          subject: e['subject'] as String?,
          concept: e['concept'] as String?,
          batchId: e['batch'] as String?,
        ),
    ];
  }

  /// Tek bir kaydın ham alanları (form önden doldurulurken).
  Future<Map<String, dynamic>?> entry(String id) async {
    for (final Map<String, dynamic> e in await _load()) {
      if (e['id'] == id) return Map<String, dynamic>.from(e);
    }
    return null;
  }

  Future<Uint8List?> bytesOf(String id) async {
    try {
      final File f = await _fileFor(id);
      if (!f.existsSync()) return null;
      return f.readAsBytesSync();
    } catch (e) {
      debugPrint('kuyruk dosyası okunamadı ($id): $e');
      return null;
    }
  }

  // ------------------------------------------------------------ boşaltma
  Future<void> drainIfPending() async {
    if ((await _load()).isEmpty) return;
    await flush();
  }

  /// Bekleyen fotoğrafları işler: önce analiz, sonra yükleme.
  ///
  /// Dönen değer: durumu DEĞİŞEN kayıt sayısı (arayüz şeridi bunu yeniliyor).
  Future<int> flush() async {
    if (_flushing) return 0;
    final String? uid = _uid();
    if (uid == null) return 0;

    _flushing = true;
    int touched = 0;
    try {
      // Boşaltma turu, budamanın doğal yeri: kuyruk zaten okunuyor ve tur
      // seyrek (öne gelme / soğuk açılış / gönderim öncesi).
      await _pruneOrphans();
      final List<Map<String, dynamic>> items = await _load();

      // Başka hesaba ait kayıtları AT: fotoğrafı yanlış kullanıcının arşivine
      // yazmak, kuyruğun önlemek için var olduğu kayıptan daha kötü olurdu.
      final List<String> foreign = <String>[
        for (final Map<String, dynamic> e in items)
          if (e['uid'] != uid) e['id'] as String,
      ];
      if (foreign.isNotEmpty) {
        items.removeWhere((Map<String, dynamic> e) => e['uid'] != uid);
        await _persist(items);
        for (final String id in foreign) {
          await _deleteFile(id);
        }
      }

      int i = 0;
      while (i < items.length) {
        final Map<String, dynamic> e = items[i];
        final String id = e['id'] as String;

        if (e['gate'] == 'age') {
          // Yaş adımı henüz tamamlanmadı. Kayıt DURUYOR; kullanıcı adımı
          // geçtiğinde `releaseAgeGate` + `flush` çalışacak.
          i++;
          continue;
        }

        final PhotoQueueState state = PhotoQueueState.fromDb(e['state'] as String?);
        if (state == PhotoQueueState.needsUser) {
          i++;
          continue;
        }

        final Uint8List? bytes = await bytesOf(id);
        if (bytes == null) {
          // Dosya yok: kayıt anlamsız. Sessizce bırakmak kuyruğu sonsuza dek
          // "1 bekliyor" gösterirdi.
          debugPrint('kuyruk dosyası kayıp, kayıt düşürüldü: $id');
          items.removeAt(i);
          await _persist(items);
          touched++;
          continue;
        }

        if (state == PhotoQueueState.needsAnalysis) {
          if (!(aiConsentOverride?.call() ?? userProfile.aiConsent)) {
            // AKTARIM ONAYI YOK (Task 03, 4.2). Onay çekim ekranında bir kez
            // isteniyor ve reddedilirse analiz hiç çağrılmıyor; bu ikinci
            // kapı, kuyruğun onayı ATLAYAN bir yol açmasını engelliyor.
            // Kayıt düşmüyor: kullanıcı elle doldurup kaydedebilir.
            debugPrint('aktarım onayı yok; kuyruk analizi atlıyor');
            e['state'] = PhotoQueueState.needsUser.dbValue;
            await _persist(items);
            touched++;
            i++;
            continue;
          }
          final QuestionAnalysis result;
          try {
            result = await (analyzeOverride?.call(bytes) ??
                mistakeRepository.analyzeQuestion(bytes));
          } catch (err) {
            // Ağ katmanı: sıra korunsun, sonraya bırak.
            debugPrint('kuyrukta analiz başarısız, sonraya bırakıldı: $err');
            break;
          }
          if (result.failure == AnalysisFailure.ageRequired) {
            // Sunucu yaş kapısını kapalı buldu. İstemci kilidi bir sebeple
            // düşmüş olabilir; kaydı düşürmüyoruz, bekletiyoruz.
            debugPrint('kuyrukta analiz yaş kapısına takıldı; bekletiliyor');
            i++;
            continue;
          }
          _mergeAnalysis(e, result);
          e['state'] = _isComplete(e)
              ? PhotoQueueState.ready.dbValue
              : PhotoQueueState.needsUser.dbValue;
          await _persist(items);
          touched++;
          // Kaydı bu turda `ready` olarak işlemeye devam et (i artmıyor).
          continue;
        }

        // ready → yükle + insert
        try {
          final Future<void> Function(Map<String, dynamic>, Uint8List)? hook =
              uploadOverride;
          if (hook != null) {
            await hook(e, bytes);
          } else {
            await submissionQueue.drainIfPending();
            await mistakeRepository.add(
              subject: e['subject'] as String,
              concept: e['concept'] as String,
              type: MistakeType.fromDb(e['type'] as String?),
              note: (e['note'] as String?) ?? '',
              imageBytes: bytes,
              options: _optionsOf(e),
              correctIndex: (e['correct_index'] as num?)?.toInt(),
              exam: e['exam'] as String?,
              extraConcepts: <String>[
                for (final dynamic x in (e['extras'] as List<dynamic>? ?? const <dynamic>[]))
                  x as String,
              ],
            );
          }
        } on PostgrestException catch (err) {
          // SUNUCU REDDETTİ — tekrar denemek aynı sonucu verir. Kaydı düşür,
          // ama SESSİZCE DEĞİL: kullanıcının fotoğrafı kayboluyor.
          debugPrint('kuyruk fotoğrafı reddedildi, düşürüldü: ${err.code} ${err.message}');
          unawaited(reportError(err, StackTrace.current,
              context: 'photoQueue.rejected'));
          items.removeAt(i);
          await _persist(items);
          await _deleteFile(id);
          touched++;
          continue;
        } on StorageException catch (err) {
          // DEPOLAMA KALICI OLARAK REDDETTİ (413 boyut, 400 mime). 0066 aynı
          // sorunu MIME için sunucuda çözdü, YÜKLEME için çözmemişti: bu dal
          // yoktu ve aşağıdaki genel `catch`e düşüyordu, yani KUYRUĞUN BAŞI
          // sonsuza dek tıkanıyordu — tekrar denemek aynı reddi üretiyor.
          debugPrint('depolama reddetti, düşürüldü: ${err.statusCode} ${err.message}');
          unawaited(reportError(err, StackTrace.current,
              context: 'photoQueue.storageRejected'));
          items.removeAt(i);
          await _persist(items);
          await _deleteFile(id);
          touched++;
          continue;
        } catch (err) {
          // BURASI İKİ HATA SINIFINI BİRDEN TAŞIYORDU ve ikisine de "sonraya
          // bırak" diyordu. Ağ hatasında bu doğru; KALICI bir istemci
          // hatasında (`e['subject'] as String` cast hatası, bozuk kayıt,
          // biçim uyumsuzluğu) tekrar denemek aynı sonucu veriyor ve kayıt
          // düşmediği için kuyruğun BAŞI SONSUZA DEK TIKANIYOR — arkasındaki
          // bütün fotoğraflar rehin kalıyor.
          //
          // Ayrım tipten: `TypeError` / `FormatException` verinin kendisinden
          // geliyor ve zamanla düzelmiyor. Geri kalan her şey (SocketException,
          // TimeoutException, FunctionException, tanınmayan) ağ sayılıyor —
          // KALICI OLDUĞUNU KANITLAYAMADIĞIMIZ hatada kullanıcının fotoğrafını
          // silmemek, kuyruğun var olma gerekçesi.
          if (err is TypeError || err is FormatException) {
            debugPrint('kuyruk kaydı bozuk, düşürüldü: $err');
            unawaited(reportError(err, StackTrace.current,
                context: 'photoQueue.corruptEntry'));
            items.removeAt(i);
            await _persist(items);
            await _deleteFile(id);
            touched++;
            continue;
          }
          debugPrint('kuyruk yüklemesi başarısız, sonraya bırakıldı: $err');
          break;
        }

        items.removeAt(i);
        await _persist(items);
        await _deleteFile(id);
        touched++;
      }
      return touched;
    } finally {
      _flushing = false;
    }
  }

  // ------------------------------------------------------------ yardımcılar
  static bool _isComplete(Map<String, dynamic> e) =>
      (e['subject'] as String?)?.isNotEmpty == true &&
      (e['concept'] as String?)?.isNotEmpty == true &&
      e['correct_index'] != null &&
      (e['labels'] as List<dynamic>? ?? const <dynamic>[]).isNotEmpty;

  static List<QuestionOption> _optionsOf(Map<String, dynamic> e) => <QuestionOption>[
        for (final dynamic l in (e['labels'] as List<dynamic>? ?? const <dynamic>[]))
          QuestionOption(label: l as String, text: ''),
      ];

  /// Analiz sonucunu kayda işler. KULLANICININ GİRDİĞİ ALANLARI EZMİYOR:
  /// çevrimdışıyken formu doldurmuş biri, sonradan gelen AI tahmini yüzünden
  /// seçtiği dersi kaybetmemeli.
  static void _mergeAnalysis(Map<String, dynamic> e, QuestionAnalysis a) {
    if (!a.ok) return;
    if (a.options.isNotEmpty &&
        (e['labels'] as List<dynamic>? ?? const <dynamic>[]).isEmpty) {
      e['labels'] = <String>[for (final QuestionOption o in a.options) o.label];
    }
    if (e['exam'] == null && (a.exam == 'TYT' || a.exam == 'AYT')) {
      e['exam'] = a.exam;
    }
    if (e['subject'] == null && a.subject != null) e['subject'] = a.subject;
    if (e['concept'] == null && a.concept != null && a.conceptValid) {
      e['concept'] = a.concept;
    }
  }
}

final PhotoQueue photoQueue = PhotoQueue.instance;
