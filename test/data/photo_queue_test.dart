import 'dart:convert';
import 'dart:io';

import 'package:ai_yks_coach/data/photo_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Çevrimdışı fotoğraf kuyruğunun KALICILIK sözleşmesi.
///
/// Neden bu testler var: kuyruğun tek işi "uygulama kapanıp açılınca kaybolma"
/// ve o söz yalnızca disk biçimi doğru okunup yazıldığında tutuyor. Bozuk bir
/// kayıt ya da yanlış hesaplanmış bir durum, kullanıcının fotoğrafını sessizce
/// yutar — kuyruğun önlemek için var olduğu kaybın ta kendisi.
///
/// KAPSAM DIŞI: `flush()`. Ağ çağrısı (`analyze-question`, storage upload)
/// gerektiriyor ve bu depoda sahte Supabase istemcisi yok (`mocktail` bilinçli
/// olarak eklenmedi). Test ortamında oturum da yok; oturumsuz davranış aşağıda
/// ayrıca iddia ediliyor.
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
}
