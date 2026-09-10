import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/curriculum_repository.dart';
import 'package:kimo/models/curriculum.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Konu ağacının istemci tarafı.
///
/// İki sözleşme kilitleniyor:
///
///  1. **Konu seçme yolu ASLA kapanmaz.** Ağaç sunucudan geliyor ama önbellek
///     boşsa (ilk kurulum) ya da bozuksa gömülü yedeğe düşülüyor. Kapanırsa
///     kullanıcı soru KAYDEDEMEZ — uygulamanın çekirdek akışı.
///  2. **Arama öğrencinin dilini anlar.** "atislar" yazan biri Fizik'i hiç
///     seçmeden `Kuvvet ve Hareket`'i bulmalı; "ucgen" yazan `Üçgenler`i.
///     Task 09'a kadar arama yalnızca seçili dersin içindeydi ve Türkçe
///     normalizasyonu yoktu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> seed([Map<String, Object> values = const <String, Object>{}]) async {
    // `setMockInitialValues` tek başına yetmiyor: `getInstance()` bir örneği
    // önbelleğe alıyor ve `reload()` olmadan bir önceki testin yazdıkları
    // sızıyor (bkz. notification_lines_test / app_settings_test).
    SharedPreferences.setMockInitialValues(values);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    curriculumRepository.resetForTest();
  }

  group('CurriculumRepository yükleme', () {
    test('önbellek yokken GÖMÜLÜ YEDEĞE düşüyor (ilk açılış + çevrimdışı)',
        () async {
      await seed();
      await curriculumRepository.load();

      final CurriculumTree tree = curriculumRepository.treeFor('eski');
      expect(tree.isEmpty, isFalse,
          reason: 'ağaç yoksa kullanıcı konu seçemez, yani soru kaydedemez');
      expect(tree.version, isNotEmpty);
      expect(tree.subjectNames('TYT'), contains('Fizik'));
      expect(tree.subjectNames('AYT'), contains('Edebiyat'));
    });

    test('gömülü yedek İKİ müfredatı da taşıyor', () async {
      await seed();
      await curriculumRepository.load();
      // Kullanıcı onboarding'de sınav yılını değiştirince müfredat da
      // değişiyor; yedek ikisini de taşımasa o an seçici boşalırdı.
      expect(curriculumRepository.treeFor('eski').isEmpty, isFalse);
      expect(curriculumRepository.treeFor('maarif').isEmpty, isFalse);
    });

    test('bozuk önbellek JSON''u seçiciyi KİLİTLEMİYOR', () async {
      await seed(<String, Object>{'curriculum.tree_v1': '{bu json değil'});
      await curriculumRepository.load();
      expect(curriculumRepository.treeFor('eski').isEmpty, isFalse,
          reason: 'bozuk tek bir kayıt yüzünden konu seçilemez olmamalı');
    });

    test('önbellek varsa gömülü yedeğin ÖNÜNE geçiyor', () async {
      await seed(<String, Object>{
        'curriculum.tree_v1': jsonEncode(<String, dynamic>{
          'eski': <String, dynamic>{
            'version': 'test-surum',
            'exams': <String, dynamic>{
              'TYT': <dynamic>[
                <String, dynamic>{
                  'subject': 'Uydurma Ders',
                  'units': <dynamic>[
                    <String, dynamic>{
                      'unit': 'Uydurma Ünite',
                      'topics': <dynamic>[
                        <String, dynamic>{'topic': 'Uydurma Konu', 'aliases': <String>[]},
                      ],
                    },
                  ],
                },
              ],
            },
          },
        }),
      });
      await curriculumRepository.load();
      final CurriculumTree tree = curriculumRepository.treeFor('eski');
      expect(tree.version, 'test-surum');
      expect(tree.subjectNames('TYT'), <String>['Uydurma Ders']);
      // Önbelleği olmayan müfredat yine yedekten geliyor.
      expect(curriculumRepository.treeFor('maarif').isEmpty, isFalse);
    });
  });

  group('trNorm — SQL ve üretici ile aynı sonuç', () {
    // Bu üç örnek `public.tr_norm` ve `tools/build_taxonomy.py` ile birebir
    // aynı çıkmak zorunda; ayrışırlarsa kullanıcının yazdığı kelime sunucunun
    // bulduğuyla eşleşmez ve bu SESSİZCE olur.
    test('Türkçe harfler ASCII''ye iniyor', () {
      expect(trNorm('Atışlar'), 'atislar');
      expect(trNorm('Üçgenler'), 'ucgenler');
      expect(trNorm('İskelet Sistemi'), 'iskelet sistemi');
      expect(trNorm('Akışkanlar (Basınç)'), 'akiskanlar (basinc)');
    });

    test('büyük I ile İ aynı yere düşüyor', () {
      expect(trNorm('Iskelet'), trNorm('İskelet'));
    });

    test('boşluklar sadeleşiyor', () {
      expect(trNorm('  eğik   atış '), 'egik atis');
    });
  });

  group('CurriculumTree arama', () {
    late CurriculumTree tree;

    setUpAll(() async {
      await seed();
      await curriculumRepository.load();
      tree = curriculumRepository.treeFor('eski');
    });

    test('ETİKET yolu: "atislar" → Kuvvet ve Hareket', () {
      // Kullanıcının verdiği örnek. "Atışlar" ağaçta BİR KONU DEĞİL; en ince
      // Fizik kalemi `Hareket ve Kuvvet` (TYT) / `Kuvvet ve Hareket` (AYT).
      // Etiket olmadan bu arama boş dönerdi.
      final List<TopicHit> hits = tree.search('AYT', 'atislar');
      expect(hits, isNotEmpty);
      expect(hits.first.topic, 'Kuvvet ve Hareket');
      expect(hits.first.subject, 'Fizik');
      expect(hits.first.matchedAlias, isNotNull,
          reason: 'eşleşmenin etiketten geldiği kullanıcıya söyleniyor');
    });

    test('şapkasız/aksansız yazım tutuyor: "ucgen" → Üçgenler', () {
      final List<TopicHit> hits = tree.search('TYT', 'ucgen');
      expect(
        hits.map((TopicHit h) => h.topic),
        contains('Üçgenlerde Temel Kavramlar'),
      );
      expect(hits.every((TopicHit h) => h.subject == 'Geometri'), isTrue);
    });

    test('ders seçmeden TÜM derslerde arıyor', () {
      // Task 09'a kadar arama yalnızca seçili dersin içindeydi.
      final Set<String> subjects =
          tree.search('TYT', 'anlam').map((TopicHit h) => h.subject).toSet();
      expect(subjects, contains('Türkçe'));
    });

    test('tam eşleşme kelime başından, kelime başı içerenden önce', () {
      final List<TopicHit> hits = tree.search('AYT', 'türev');
      expect(hits.first.topic, 'Türev', reason: 'tam eşleşme başta');
      expect(
        hits.map((TopicHit h) => h.topic),
        contains('Türev Uygulamaları'),
      );
      expect(hits.indexWhere((TopicHit h) => h.topic == 'Türev'),
          lessThan(hits.indexWhere((TopicHit h) => h.topic == 'Türev Uygulamaları')));
    });

    test('seçili ders eşitlikte öne geçiyor', () {
      // "dalgalar" hem Fizik'te konu hem başka derslerde ünite/etiket olabilir.
      final List<TopicHit> withPref =
          tree.search('AYT', 'elektrik', preferSubject: 'Fizik');
      expect(withPref.first.subject, 'Fizik');
    });

    test('boş sorgu boş sonuç (gezinme yoluna düşülüyor)', () {
      expect(tree.search('TYT', '   '), isEmpty);
    });

    test('eşleşmeyen sorgu boş dönüyor, çökmüyor', () {
      expect(tree.search('TYT', 'zzzqqq'), isEmpty);
    });
  });

  group('CurriculumTree doğrulama', () {
    late CurriculumTree tree;

    setUpAll(() async {
      await seed();
      await curriculumRepository.load();
      tree = curriculumRepository.treeFor('eski');
    });

    test('ağaçtaki konu geçerli, uydurma konu değil', () {
      // Sunucudaki `is_valid_topic` ile AYNI kararı vermeli: aynı ağaç,
      // birebir ad. Ayrışırlarsa kullanıcı seçicide gördüğü konuyu
      // kaydedemez ve sebebini anlamaz.
      expect(tree.isValidTopic('AYT', 'Fizik', 'Kuvvet ve Hareket'), isTrue);
      expect(tree.isValidTopic('AYT', 'Fizik', 'Atışlar'), isFalse,
          reason: 'etiket bir konu DEĞİL; kaydedilen ad kanonik olmalı');
      expect(tree.isValidTopic('TYT', 'Fizik', 'Kuvvet ve Hareket'), isFalse,
          reason: 'sınav ayrımı korunuyor (TYT karşılığı "Hareket ve Kuvvet")');
      expect(tree.isValidTopic('AYT', 'Uydurma', 'Kuvvet ve Hareket'), isFalse);
    });

    test('aranan her sonuç GEÇERLİ bir konu', () {
      // Arama etiketten eşleşse bile döndürdüğü `topic` kanonik olmalı;
      // aksi hâlde seçici sunucunun reddedeceği bir değer üretirdi.
      for (final TopicHit h in tree.search('AYT', 'atislar')) {
        expect(tree.isValidTopic('AYT', h.subject, h.topic), isTrue);
      }
    });
  });
}
