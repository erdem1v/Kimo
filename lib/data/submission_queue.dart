import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_config.dart';

/// Cevap gönderimleri için KALICI kuyruk.
///
/// Neden var: XP artık sunucuda hesaplanıyor (bkz. 0034 göçü). Ağ yokken
/// gönderim başarısız olur; kuyruk olmasaydı cevap kaybolur ve bir sonraki
/// açılışta `hydrate()` sunucudaki eski değeri geri yükleyerek kullanıcıya
/// **ilerlemesi silinmiş gibi** gösterirdi. Bu, düzeltmenin kendi yarattığı bir
/// gerileme olurdu — eski istemcinin 403 alıp sessizce XP kaybetmesi senaryosunu
/// reddederken çevrimdışı kullanıcı için aynısını kabul etmek tutarsız olurdu.
///
/// KAPSAM: dört cevaplama akışının hepsi — `pool`, `sent`, `review`, `goal`.
/// Yani ağ yokken hiçbir cevap kaybolmuyor.
///
/// Havuz ve arkadaştan gelen sorularda bir kabul var: doğruluğu sunucu
/// belirlediği için çevrimdışıyken SONUÇ GÖSTERİLEMİYOR. Kullanıcı "cevabın
/// kaydedildi, sonucu bağlantı gelince göreceksin" bilgisini alıyor. Sonucu
/// gösterememek, cevabın kaybolmasından iyidir.
///
/// Semantik: **en az bir kez**. Yanıt kaybolursa aynı gönderim tekrar denenir,
/// dolayısıyla her akış idempotent olmak zorunda:
///   • `submit_pool_answer` → `question_attempts` birincil anahtarı
///   • `submit_sent_answer` → `solved_at is null` koşulu
///   • `claim_daily_goal`   → `daily_goal_date`
///   • `submit_review`      → istemcinin ürettiği tek seferlik `p_token`
///
/// Kuyruk SIRAYI korur. Başarısızlıkta ne yapıldığı hata TÜRÜNE bağlı:
///   • ağ hatası      → DUR, sıra korunsun (sonraki denemede baştan devam)
///   • sunucu reddi   → kaydı DÜŞÜR ve devam et
/// İkinci dal şart: kalıcı bir ret (ör. kullanıcı çevrimdışıyken kendi
/// hatasını sildi) koşulsuz durdurmada kuyruğun başını sonsuza dek tıkıyor,
/// arkasındaki bütün cevapları öldürüyordu — yani kuyruk, önlemek için
/// yazıldığı kaybın daha kötüsünü üretiyordu.
class SubmissionQueue {
  SubmissionQueue._();
  static final SubmissionQueue instance = SubmissionQueue._();

  static const String _storageKey = 'pending_submissions_v1';

  /// Kuyruğun sınırsız büyümesini engeller: bu sayının üstündeki en eski
  /// gönderimler düşürülür. Çok uzun süre çevrimdışı kalan bir cihazda
  /// sınırsız birikmesindense en yenileri korumak daha doğru.
  static const int _maxEntries = 200;

  SupabaseClient get _client => Supabase.instance.client;

  List<Map<String, dynamic>>? _cache;
  bool _flushing = false;

  // NOT: burada senkron bir `pendingCount` getter'ı vardı. Kaldırıldı —
  // yalnızca belleği okuduğu için SOĞUK AÇILIŞTA, disk dolu olsa bile 0
  // döndürüyordu. Yani göstergeye bağlansaydı tam da en çok gerektiği anda
  // "bekleyen yok" derdi. Yerine diskten okuyan [loadPendingCount] var.

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
      // Bozuk kayıt kuyruğu kalıcı olarak kilitlemesin.
      debugPrint('gönderim kuyruğu okunamadı: $e');
      return _cache = <Map<String, dynamic>>[];
    }
  }

  Future<void> _persist(List<Map<String, dynamic>> items) async {
    _cache = items;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(items));
    } catch (e) {
      debugPrint('gönderim kuyruğu yazılamadı: $e');
    }
  }

  /// Gönderimi kuyruğa alır (ağ hatasından sonra çağrılır).
  ///
  /// Kayda oturumdaki kullanıcının kimliği de yazılır: aynı cihazda hesap
  /// değişirse bir kullanıcının bekleyen cevapları DİĞERİNİN hesabına
  /// yazılmamalı. Çıkışta kuyruğu temizlemeye güvenmek yetmez — çıkış akışı
  /// çağrılmadan da (çökme, jeton süresi dolması) hesap değişebilir.
  /// Kuyruğa gerçekten eklendiyse true döner.
  ///
  /// Oturum yoksa (jeton yenilenemedi, oturum düştü) kayıt DÜŞÜYOR — o durumda
  /// çağıran kullanıcıya "kaydedildi" DEMEMELİ. Eskiden void dönüyordu ve
  /// arayüz her hâlükârda "kaydedildi" diyordu.
  Future<bool> enqueue(Map<String, dynamic> entry) async {
    if (!SupabaseConfig.isConfigured) return false;
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) {
      debugPrint('oturum yok: gönderim kuyruğa ALINAMADI');
      return false;
    }
    final List<Map<String, dynamic>> items = await _load();
    items.add(<String, dynamic>{...entry, 'uid': uid});
    if (items.length > _maxEntries) {
      items.removeRange(0, items.length - _maxEntries);
    }
    await _persist(items);
    return true;
  }

  /// Oturum kapanınca çağrılır: bekleyen kayıtlar diskte kalmasın.
  Future<void> clear() async {
    // Nesneyi DEĞİŞTİRMİYORUZ, içeriğini boşaltıyoruz: devam eden bir flush
    // aynı listeyi tutuyor olabilir ve nesneyi değiştirmek onun bir sonraki
    // _persist çağrısında eski kayıtları diske geri yazmasına yol açardı.
    final List<Map<String, dynamic>> items = await _load();
    items.clear();
    await _persist(items);
  }

  /// Diskteki bekleyen kayıt sayısı (önbellek henüz dolmamışsa okur).
  ///
  /// [pendingCount] yalnızca belleği okuduğu için soğuk açılışta 0 döner;
  /// gösterge ve tetikleyiciler bu yüzden bunu kullanmalı.
  Future<int> loadPendingCount() async => (await _load()).length;

  /// Bekleyen kayıt varsa kuyruğu boşaltmayı dener.
  ///
  /// Başarılı bir gönderimden ÖNCE çağrılır: bir istek geçecekse ağ geri gelmiş
  /// demektir ve birikmiş cevapların bir sonraki SOĞUK AÇILIŞI beklemesi için
  /// sebep yok. Önce boşaltmanın nedeni sıralama: asıl isteğin yanıtındaki
  /// toplamlar böylece en güncel durumu yansıtıyor ve ekran tek bir yerde
  /// uzlaştırma yapıyor.
  ///
  /// Kuyruk boşsa bu bir no-op; hiç ağ isteği yapılmıyor.
  Future<void> drainIfPending() async {
    if (!SupabaseConfig.isConfigured) return;
    if ((await _load()).isEmpty) return;
    await flush();
  }

  /// Bekleyen gönderimleri sırayla dener.
  ///
  /// Dönen değer: sunucudan gelen SON toplamlar (varsa). Çağıran bunu
  /// `GameProgress.applyServerTotals` ile uygular, böylece yerel iyimser
  /// değerler sunucununkiyle uzlaşır.
  Future<Map<String, dynamic>?> flush() async {
    if (_flushing || !SupabaseConfig.isConfigured) return null;
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    _flushing = true;
    try {
      final List<Map<String, dynamic>> items = await _load();

      // Başka bir hesaba ait kayıtları AT: onları bu oturumla göndermek
      // cevapları yanlış kullanıcıya yazardı.
      final int before = items.length;
      items.removeWhere((Map<String, dynamic> e) => e['uid'] != uid);
      if (items.length != before) {
        debugPrint('kuyruktan ${before - items.length} yabancı kayıt atıldı');
        await _persist(items);
      }

      Map<String, dynamic>? last;
      while (items.isNotEmpty) {
        try {
          last = await _send(items.first);
        } on PostgrestException catch (e) {
          // SUNUCU YANIT VERDİ VE REDDETTİ — tekrar denemek aynı sonucu verir.
          //
          // Bu dalı ayırmak şart: eskiden her hata `break` ediyordu ve kalıcı
          // bir ret (ör. kullanıcı çevrimdışıyken kendi hatasını sildi →
          // submit_review 42501 döndürür) kuyruğun BAŞINI sonsuza dek
          // tıkıyordu. Arkasındaki bütün cevaplar da ölüyordu; tek çıkış
          // oturum kapatmaktı. Yani kuyruk, yazılma sebebi olan hatanın daha
          // kötüsünü üretiyordu.
          debugPrint('kuyruk kaydı sunucuca reddedildi, düşürüldü: ${e.code} ${e.message}');
          items.removeAt(0);
          await _persist(items);
          continue;
        } catch (e) {
          // Ağ katmanı hatası: sıra korunmalı, sonraya bırak.
          debugPrint('kuyruk gönderimi başarısız, sonraya bırakıldı: $e');
          break;
        }
        items.removeAt(0);
        await _persist(items);
      }
      return last;
    } finally {
      _flushing = false;
    }
  }

  /// Tek bir gönderimi sunucuya iletir ve dönen toplamları verir.
  Future<Map<String, dynamic>?> _send(Map<String, dynamic> e) async {
    final String kind = e['kind'] as String? ?? '';
    switch (kind) {
      case 'pool':
        return _one('submit_pool_answer', <String, dynamic>{
          'p_mistake': e['mistake_id'],
          'p_choice': e['choice'],
        });
      case 'sent':
        return _one('submit_sent_answer', <String, dynamic>{
          'p_send': e['send_id'],
          'p_choice': e['choice'],
        });
      case 'review':
        return _one('submit_review', <String, dynamic>{
          'p_mistake': e['mistake_id'],
          'p_correct': e['correct'],
          // Eski kayıtlarda yok; null gidince sunucu beyana düşer.
          'p_choice': e['choice'],
          'p_token': e['token'],
        });
      case 'goal':
        return _one('claim_daily_goal', <String, dynamic>{});
      default:
        // Bilinmeyen kayıt türü (eski sürümden kalmış olabilir): at.
        debugPrint('bilinmeyen kuyruk kaydı düşürüldü: $kind');
        return null;
    }
  }

  Future<Map<String, dynamic>?> _one(
    String fn,
    Map<String, dynamic> params,
  ) async {
    final dynamic res = await _client.rpc<dynamic>(fn, params: params);
    if (res is List && res.isNotEmpty) {
      return (res.first as Map).cast<String, dynamic>();
    }
    if (res is Map) return res.cast<String, dynamic>();
    return null;
  }
}

final SubmissionQueue submissionQueue = SubmissionQueue.instance;

/// `submit_review` için tek seferlik anahtar (UUID v4).
///
/// Kuyruk en-az-bir-kez gönderim yaptığı için aynı tekrarın iki kez
/// uygulanmaması gerekiyor; sunucu bu anahtarı `submission_tokens` tablosunda
/// tutup ikinci çağrıyı yok sayıyor. Depoda `uuid` paketi yok ve tek bir yer
/// için bağımlılık eklemeye değmez.
String newSubmissionToken() {
  final Random r = Random.secure();
  final List<int> b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // sürüm 4
  b[8] = (b[8] & 0x3f) | 0x80; // varyant 10x
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
      '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}
