import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:kimo/data/photo_queue.dart';
import 'package:kimo/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Çevrimdışı fotoğraf kuyruğunun KALICILIK sözleşmesi.
///
/// Neden bu testler var: kuyruğun tek işi "uygulama kapanıp açılınca kaybolma"
/// ve o söz yalnızca disk biçimi doğru okunup yazıldığında tutuyor. Bozuk bir
/// kayıt ya da yanlış hesaplanmış bir durum, kullanıcının fotoğrafını sessizce
/// yutar — kuyruğun önlemek için var olduğu kaybın ta kendisi.
///
/// `flush()` ARTIK KAPSAM İÇİNDE (Task 12 · P1). Eskiden kapsam dışıydı çünkü
/// ağ çağrısı gerektiriyordu ve sahte Supabase istemcisi yok. Çözüm ağı taklit
/// etmek değil: sınanması gereken yan KARAR AĞACI (sıranın korunması,
/// `needsUser`ın atlanması, hangi hatada kaydın düşürüldüğü) ve o, ağa giden
/// üç çağrıyı dışarıdan vermekle sınanabiliyor. `PhotoQueue`ın
/// `directoryOverride` deseni aynı amaçla zaten vardı; `mocktail` hâlâ
/// eklenmedi.
///
/// NEDEN ÖNEMLİ: kuyruğun en riskli kısmı tam buydu ve hiç doğrulanmıyordu.
/// İki gerçek hata bu testler yazılırken kapandı — kalıcı bir istemci hatası
/// kuyruğun BAŞINI sonsuza dek tıkıyordu ve `StorageException` için ayrı dal
/// yoktu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  /// Kuyruğun disk biçimindeki tek kayıt.
  Map<String, dynamic> row(
    String id, {
    String state = 'needsAnalysis',
    String? gate,
    String uid = 'u1',
    String? subject,
    String? concept,
    int? correctIndex,
    List<String>? labels,
  }) =>
      <String, dynamic>{
        'id': id,
        'uid': uid,
        'bytes': 1024,
        'created_at': DateTime.utc(2026, 9, 6, 12).toIso8601String(),
        'state': state,
        'gate': gate,
        'subject': ?subject,
        'concept': ?concept,
        'correct_index': ?correctIndex,
        'labels': ?labels,
      };

  Future<void> seed(List<Map<String, dynamic>> rows) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pending_photos_v1': jsonEncode(rows),
    });
    photoQueue.debugResetCache();
    // Kayıtların dosyaları da olsun: silme yollarının dosyayı gerçekten
    // kaldırdığını iddia edebilmek için.
    for (final Map<String, dynamic> r in rows) {
      File('${dir.path}/${r['id']}.jpg').writeAsBytesSync(<int>[1, 2, 3]);
    }
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kimo_photo_queue');
    PhotoQueue.directoryOverride = dir;
  });

  tearDown(() {
    PhotoQueue.directoryOverride = null;
    PhotoQueue.debugResetSeams();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('PhotoQueue diskten okuma', () {
    test('boş prefs boş kuyruk verir', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      photoQueue.debugResetCache();
      expect(await photoQueue.loadPendingCount(), 0);
      expect(await photoQueue.list(), isEmpty);
    });

    test('bozuk JSON kuyruğu KİLİTLEMEZ, boş sayar', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pending_photos_v1': '{bu json değil',
      });
      photoQueue.debugResetCache();
      // Fırlatmamalı: bozuk tek bir kayıt yüzünden kullanıcı bir daha hiç
      // fotoğraf çekememeliydi — SubmissionQueue'nun aynı dersi.
      expect(await photoQueue.loadPendingCount(), 0);
    });

    test('kayıtlar durum ve yaş kilidiyle birlikte okunuyor', () async {
      await seed(<Map<String, dynamic>>[
        row('a', gate: 'age'),
        row('b', state: 'needsUser', subject: 'Matematik', concept: 'Türev'),
      ]);
      final List<PendingPhoto> items = await photoQueue.list();
      expect(items.length, 2);
      expect(items.first.id, 'a');
      expect(items.first.gatedByAge, isTrue);
      expect(items.first.state, PhotoQueueState.needsAnalysis);
      expect(items[1].gatedByAge, isFalse);
      expect(items[1].state, PhotoQueueState.needsUser);
      expect(items[1].subject, 'Matematik');
    });

    test('bilinmeyen durum kullanıcı eylemine düşer (kapalı taraf)', () async {
      await seed(<Map<String, dynamic>>[row('a', state: 'bilinmeyen')]);
      final List<PendingPhoto> items = await photoQueue.list();
      // Kaydı "gönderilmeye hazır" saymak, eksik veriyle sunucuya gitmesine
      // yol açardı; "kullanıcı baksın" güvenli taraf.
      expect(items.single.state, PhotoQueueState.needsUser);
    });
  });

  group('PhotoQueue.update durumu yeniden hesaplıyor', () {
    test('zorunlu alanlar dolunca ready olur', () async {
      await seed(<Map<String, dynamic>>[row('a', state: 'needsUser')]);
      await photoQueue.update('a', <String, dynamic>{
        'subject': 'Fizik',
        'concept': 'Kuvvet',
        'labels': <String>['A', 'B', 'C', 'D'],
        'correct_index': 2,
      });
      expect((await photoQueue.list()).single.state, PhotoQueueState.ready);
    });

    test('doğru şık eksikse ready OLMAZ', () async {
      await seed(<Map<String, dynamic>>[row('a', state: 'needsUser')]);
      await photoQueue.update('a', <String, dynamic>{
        'subject': 'Fizik',
        'concept': 'Kuvvet',
        'labels': <String>['A', 'B', 'C', 'D'],
      });
      expect(
        (await photoQueue.list()).single.state,
        PhotoQueueState.needsUser,
        reason: 'şık işaretlenmeden kayıt sunucuya gitmemeli (§5 kuralı)',
      );
    });

    test('şık listesi boşsa ready OLMAZ', () async {
      await seed(<Map<String, dynamic>>[row('a', state: 'needsUser')]);
      await photoQueue.update('a', <String, dynamic>{
        'subject': 'Fizik',
        'concept': 'Kuvvet',
        'labels': <String>[],
        'correct_index': 0,
      });
      expect((await photoQueue.list()).single.state, PhotoQueueState.needsUser);
    });
  });

  group('PhotoQueue silme yolları dosyayı da siler', () {
    test('remove tek kaydı ve dosyasını kaldırır', () async {
      await seed(<Map<String, dynamic>>[row('a'), row('b')]);
      await photoQueue.remove('a');
      expect((await photoQueue.list()).single.id, 'b');
      expect(File('${dir.path}/a.jpg').existsSync(), isFalse);
      expect(File('${dir.path}/b.jpg').existsSync(), isTrue);
    });

    test('purgeAgeGated YALNIZCA yaş kilitli kayıtları siler', () async {
      // 13 altı reddedildiğinde çalışıyor: o fotoğraf hiç analiz edilmemeli ve
      // cihazda da bırakılmamalı. Ama kullanıcının diğer kayıtları duruyor.
      await seed(<Map<String, dynamic>>[
        row('kilitli', gate: 'age'),
        row('serbest'),
      ]);
      await photoQueue.purgeAgeGated();
      expect((await photoQueue.list()).single.id, 'serbest');
      expect(File('${dir.path}/kilitli.jpg').existsSync(), isFalse);
      expect(File('${dir.path}/serbest.jpg').existsSync(), isTrue);
    });

    test('releaseAgeGate kilidi kaldırır ama kaydı silmez', () async {
      await seed(<Map<String, dynamic>>[row('a', gate: 'age')]);
      await photoQueue.releaseAgeGate();
      final PendingPhoto p = (await photoQueue.list()).single;
      expect(p.gatedByAge, isFalse);
      expect(File('${dir.path}/a.jpg').existsSync(), isTrue);
    });

    test('clear her şeyi siler (oturum kapanışı)', () async {
      await seed(<Map<String, dynamic>>[row('a'), row('b', gate: 'age')]);
      await photoQueue.clear();
      expect(await photoQueue.loadPendingCount(), 0);
      expect(dir.listSync(), isEmpty,
          reason: 'başka hesap açıldığında cihazda yabancı fotoğraf kalmamalı');
    });
  });

  group('PhotoQueue sayaçlar ve okuma', () {
    test('loadNeedsUserCount yalnızca kullanıcı eylemi bekleyenleri sayar',
        () async {
      await seed(<Map<String, dynamic>>[
        row('a', state: 'needsUser'),
        row('b', state: 'needsAnalysis'),
        row('c', state: 'ready'),
        row('d', state: 'needsUser'),
      ]);
      expect(await photoQueue.loadPendingCount(), 4);
      expect(await photoQueue.loadNeedsUserCount(), 2);
    });

    test('entry ham alanları döndürür, bytesOf dosyayı okur', () async {
      await seed(<Map<String, dynamic>>[row('a', subject: 'Kimya')]);
      final Map<String, dynamic>? e = await photoQueue.entry('a');
      expect(e?['subject'], 'Kimya');
      expect(await photoQueue.bytesOf('a'), <int>[1, 2, 3]);
    });

    test('dosyası olmayan kayıtta bytesOf null döner', () async {
      await seed(<Map<String, dynamic>>[row('a')]);
      File('${dir.path}/a.jpg').deleteSync();
      expect(await photoQueue.bytesOf('a'), isNull);
    });
  });

  // ==========================================================================
  // flush() — KARAR AĞACI
  // ==========================================================================
  group('flush karar ağacı', () {
    /// Tam kayıt: `_isComplete` geçiyor, yani doğrudan `ready` işlenebilir.
    Map<String, dynamic> full(String id, {String state = 'ready'}) => row(
          id,
          state: state,
          subject: 'Matematik',
          concept: 'Köklü Sayılar',
          correctIndex: 2,
          labels: <String>['A', 'B', 'C', 'D', 'E'],
        );

    setUp(() {
      PhotoQueue.uidOverride = 'u1';
      PhotoQueue.aiConsentOverride = () => true;
    });

    test('oturum yoksa hiçbir şey yapmıyor', () async {
      PhotoQueue.uidOverride = null;
      await seed(<Map<String, dynamic>>[full('a')]);
      // Dikiş yok VE gerçek istemci de kurulu değil: erişimin kendisi
      // fırlatmasın diye `flush` uid'i ilk satırda okuyor.
      expect(() => photoQueue.flush(), throwsA(anything));
    });

    test('ready kayıt yüklenip SİLİNİYOR, dosyası da gidiyor', () async {
      await seed(<Map<String, dynamic>>[full('a')]);
      final List<String> uploaded = <String>[];
      PhotoQueue.uploadOverride = (Map<String, dynamic> e, _) async {
        uploaded.add(e['id'] as String);
      };
      expect(await photoQueue.flush(), 1);
      expect(uploaded, <String>['a']);
      expect(await photoQueue.loadPendingCount(), 0);
      expect(File('${dir.path}/a.jpg').existsSync(), isFalse);
    });

    test('needsUser ATLANIYOR — arkasındakini rehin almıyor', () async {
      await seed(<Map<String, dynamic>>[
        row('a', state: 'needsUser'),
        full('b'),
      ]);
      final List<String> uploaded = <String>[];
      PhotoQueue.uploadOverride = (Map<String, dynamic> e, _) async {
        uploaded.add(e['id'] as String);
      };
      await photoQueue.flush();
      expect(uploaded, <String>['b'], reason: 'b, a yüzünden beklemiyor');
      expect(await photoQueue.loadPendingCount(), 1, reason: 'a duruyor');
    });

    test('yaş kapılı kayıt işlenmiyor ve DÜŞMÜYOR', () async {
      await seed(<Map<String, dynamic>>[full('a', state: 'ready')..['gate'] = 'age']);
      PhotoQueue.uploadOverride = (_, _) async => throw StateError('çağrılmamalı');
      expect(await photoQueue.flush(), 0);
      expect(await photoQueue.loadPendingCount(), 1);
    });

    test('başka hesabın kaydı ATILIYOR', () async {
      await seed(<Map<String, dynamic>>[full('a')..['uid'] = 'baskasi']);
      expect(await photoQueue.flush(), 0);
      expect(await photoQueue.loadPendingCount(), 0);
      expect(File('${dir.path}/a.jpg').existsSync(), isFalse);
    });

    test('dosyası kayıp kayıt düşürülüyor', () async {
      await seed(<Map<String, dynamic>>[full('a')]);
      File('${dir.path}/a.jpg').deleteSync();
      expect(await photoQueue.flush(), 1);
      expect(await photoQueue.loadPendingCount(), 0);
    });

    test('AĞ hatasında sıra korunuyor: kayıt DURUYOR', () async {
      await seed(<Map<String, dynamic>>[full('a'), full('b')]);
      PhotoQueue.uploadOverride = (_, _) async =>
          throw const SocketException('bağlantı yok');
      expect(await photoQueue.flush(), 0);
      expect(await photoQueue.loadPendingCount(), 2, reason: 'ikisi de duruyor');
      expect(File('${dir.path}/a.jpg').existsSync(), isTrue);
    });

    test('KALICI istemci hatası kuyruğun başını TIKAMIYOR', () async {
      // Bu testin yakaladığı hata: eski `catch (err) { break; }` bir cast
      // hatasını ağ hatası gibi ele alıyordu, kayıt düşmüyordu ve arkasındaki
      // her fotoğraf sonsuza dek rehin kalıyordu.
      await seed(<Map<String, dynamic>>[full('a'), full('b')]);
      int calls = 0;
      PhotoQueue.uploadOverride = (Map<String, dynamic> e, _) async {
        calls++;
        if (e['id'] == 'a') throw const FormatException('bozuk kayıt');
      };
      await photoQueue.flush();
      expect(calls, 2, reason: 'b de denendi — kuyruk tıkanmadı');
      expect(await photoQueue.loadPendingCount(), 0, reason: 'a düştü, b gitti');
      expect(File('${dir.path}/a.jpg').existsSync(), isFalse);
    });

    test('needsAnalysis → analiz eksik bilgi verirse needsUser oluyor', () async {
      await seed(<Map<String, dynamic>>[row('a', state: 'needsAnalysis')]);
      PhotoQueue.analyzeOverride = (_) async => const QuestionAnalysis(
            ok: false,
            options: <QuestionOption>[],
            failure: AnalysisFailure.unreadable,
          );
      PhotoQueue.uploadOverride = (_, _) async => throw StateError('çağrılmamalı');
      await photoQueue.flush();
      final List<PendingPhoto> left = await photoQueue.list();
      expect(left.single.state, PhotoQueueState.needsUser);
    });

    test('analiz eksiksiz dönerse AYNI TURDA yükleniyor', () async {
      await seed(<Map<String, dynamic>>[row('a', state: 'needsAnalysis')]);
      PhotoQueue.analyzeOverride = (_) async => const QuestionAnalysis(
            ok: true,
            options: <QuestionOption>[
              QuestionOption(label: 'A', text: ''),
              QuestionOption(label: 'B', text: ''),
            ],
            subject: 'Fizik',
            concept: 'Basınç',
            conceptValid: true,
            exam: 'TYT',
          );
      // `correct_index` AI'dan gelmiyor (asla gelmez); kullanıcı girmiş olsun.
      final List<String> uploaded = <String>[];
      PhotoQueue.uploadOverride = (Map<String, dynamic> e, _) async {
        uploaded.add(e['id'] as String);
      };
      await photoQueue.flush();
      // Şık ve konu geldi ama doğru şık YOK → kayıt kullanıcıyı bekliyor.
      expect(uploaded, isEmpty);
      expect((await photoQueue.list()).single.state, PhotoQueueState.needsUser);
      expect((await photoQueue.entry('a'))?['subject'], 'Fizik');
    });

    test('yaş kapısı sunucudan gelirse kayıt BEKLETİLİYOR', () async {
      await seed(<Map<String, dynamic>>[row('a', state: 'needsAnalysis')]);
      PhotoQueue.analyzeOverride = (_) async => const QuestionAnalysis(
            ok: false,
            options: <QuestionOption>[],
            failure: AnalysisFailure.ageRequired,
          );
      await photoQueue.flush();
      expect((await photoQueue.list()).single.state,
          PhotoQueueState.needsAnalysis,
          reason: 'yaş kapısı needsUser DEĞİL — kullanıcı yılı yazınca çözülür');
    });

    test('aktarım onayı yoksa analiz HİÇ çağrılmıyor', () async {
      PhotoQueue.aiConsentOverride = () => false;
      await seed(<Map<String, dynamic>>[row('a', state: 'needsAnalysis')]);
      PhotoQueue.analyzeOverride = (_) async => throw StateError('çağrılmamalı');
      await photoQueue.flush();
      expect((await photoQueue.list()).single.state, PhotoQueueState.needsUser);
    });
  });

  // ==========================================================================
  // _pruneOrphans — 30 MB kapısına SAYILMAYAN sızıntı
  // ==========================================================================
  group('yetim dosya budama', () {
    test('üstverisi olmayan ESKİ dosya siliniyor', () async {
      await seed(<Map<String, dynamic>>[]);
      final File orphan = File('${dir.path}/yetim.jpg')
        ..writeAsBytesSync(<int>[9]);
      // Yarış penceresinin (60 sn) dışına taşı.
      orphan.setLastModifiedSync(
          DateTime.now().subtract(const Duration(minutes: 5)));
      PhotoQueue.uidOverride = 'u1';
      await photoQueue.flush();
      expect(orphan.existsSync(), isFalse);
    });

    test('TAZE dosyaya dokunulmuyor — enqueue yarışı kapalı', () async {
      // `enqueue` önce dosyayı yazıyor, sonra üstveriyi kalıcılaştırıyor.
      // Araya giren bir budama geçerli bir fotoğrafı silerdi.
      await seed(<Map<String, dynamic>>[]);
      final File fresh = File('${dir.path}/taze.jpg')
        ..writeAsBytesSync(<int>[9]);
      PhotoQueue.uidOverride = 'u1';
      await photoQueue.flush();
      expect(fresh.existsSync(), isTrue);
    });

    test('kayıtlı dosya budanmıyor', () async {
      await seed(<Map<String, dynamic>>[row('a', state: 'needsUser')]);
      final File keep = File('${dir.path}/a.jpg');
      keep.setLastModifiedSync(
          DateTime.now().subtract(const Duration(minutes: 5)));
      PhotoQueue.uidOverride = 'u1';
      await photoQueue.flush();
      expect(keep.existsSync(), isTrue);
    });
  });

  // ==========================================================================
  // Task 12 · P5 — PARTİ DESTEĞİ
  // ==========================================================================
  group('parti', () {
    test('batchLimitFor: bellek sinyali yoksa TAM sınır', () {
      // Sinyal bağlı değil (`device_info_plus` gerekiyor) ve sınırı sebepsiz
      // düşürmek cihazların çoğunu cezalandırırdı — asıl koruma disk deseni.
      expect(PhotoQueue.batchLimitFor(null), PhotoQueue.batchMax);
      expect(PhotoQueue.batchMax, 10, reason: 'tasarım: tek seferde 10');
    });

    test('batchLimitFor: 3 GB ve altı düşük bellek kademesi', () {
      expect(PhotoQueue.batchLimitFor(2048), PhotoQueue.batchMaxLowMemory);
      expect(PhotoQueue.batchLimitFor(3072), PhotoQueue.batchMaxLowMemory);
      expect(PhotoQueue.batchLimitFor(4096), PhotoQueue.batchMax);
      expect(PhotoQueue.batchMaxLowMemory, 3);
    });

    test('freeSlots kuyruktaki yeri söylüyor — parti ÖNCESİNDE', () async {
      // İki parti kuyruğu tam dolduruyor (20 kayıt). Önden sormayınca
      // kullanıcı 10 kare çekiyor ve bir kısmı sessizce reddediliyor.
      await seed(<Map<String, dynamic>>[]);
      expect(await photoQueue.freeSlots(), PhotoQueue.maxEntries);
      await seed(<Map<String, dynamic>>[
        for (int i = 0; i < 15; i++) row('r$i', state: 'needsUser'),
      ]);
      expect(await photoQueue.freeSlots(), 5);
    });

    test('parti damgası kayıtta ve listede taşınıyor', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      photoQueue.debugResetCache();
      PhotoQueue.uidOverride = 'u1';
      await photoQueue.enqueue(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        state: PhotoQueueState.needsAnalysis,
        batchId: 'b42',
      );
      await photoQueue.enqueue(
        bytes: Uint8List.fromList(<int>[4, 5, 6]),
        state: PhotoQueueState.needsAnalysis,
      );
      final List<PendingPhoto> all = await photoQueue.list();
      expect(all.length, 2);
      expect(all.where((PendingPhoto p) => p.batchId == 'b42').length, 1);
      // Damgasız kayıt = tek kare (bugünkü yol); `null` kalıyor.
      expect(all.where((PendingPhoto p) => p.batchId == null).length, 1);
    });

    test('parti kayıtları flush ile sırayla işleniyor', () async {
      await seed(<Map<String, dynamic>>[
        row('a', state: 'needsAnalysis')..['batch'] = 'b1',
        row('b', state: 'needsAnalysis')..['batch'] = 'b1',
      ]);
      PhotoQueue.uidOverride = 'u1';
      PhotoQueue.aiConsentOverride = () => true;
      final List<String> analyzed = <String>[];
      PhotoQueue.analyzeOverride = (_) async {
        analyzed.add('x');
        return const QuestionAnalysis(
          ok: false,
          options: <QuestionOption>[],
          failure: AnalysisFailure.unreadable,
          refunded: true,
        );
      };
      await photoQueue.flush();
      expect(analyzed.length, 2, reason: 'iki kare de denendi');
      // İkisi de kullanıcıyı bekliyor: okunamadı ama KAYBOLMADI.
      final List<PendingPhoto> left = await photoQueue.list();
      expect(left.length, 2);
      expect(
        left.every((PendingPhoto p) => p.state == PhotoQueueState.needsUser),
        isTrue,
      );
    });
  });
}
