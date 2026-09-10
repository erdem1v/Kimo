import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/curriculum.dart';
import '../services/crash_service.dart';
import '../services/supabase_config.dart';

/// Konu ağacının istemci tarafı.
///
/// **Ağaç kodda değil veride.** Tek çalışma zamanı kaynağı veritabanı (göç
/// 0071); istemci onu `curriculum_tree` RPC'siyle çekip diske önbelliyor.
/// Task 09'a kadar aynı ağaç `yks_curriculum.dart` içinde elle yazılıydı,
/// `analyze-question/taxonomy.ts` ikinci kopyasını taşıyordu ve senkronu
/// garanti eden tek şey bir yorum satırıydı.
///
/// `notification_lines.dart` desenini izliyor — depoda "sunucudan çek + diske
/// önbellekle"nin tek örneği: tekil sınıf, sürümlü prefs anahtarı, `load()`
/// açılışta AWAIT (ucuz, ağsız), `refresh()` ateşle-unut, hata SESSİZ (eski
/// önbellek çalışmaya devam eder), `resetForTest()`.
///
/// O desenden **iki bilinçli fark**:
///
/// 1. **Sürüm pazarlığı var.** Bildirim metinleri her tazelemede tümüyle
///    iniyor; ağaç 434 konu + 547 etiket olduğu için `p_known_version` ile
///    "değişmedi" cevabı alınıyor ve çoğu tazeleme birkaç bayta iniyor.
/// 2. **`ChangeNotifier`.** Ağaç tazelenince açık ekranların (konu seçici,
///    onay ekranı, "Bugün") kendini yenilemesi gerekiyor.
///
/// **Gömülü yedek** (`assets/curriculum/tree.json`) `notification_lines`'ın
/// koda gömülü yedek cümleleriyle aynı işi görüyor ama daha kritik: ağaç
/// yoksa kullanıcı KONU SEÇEMEZ, yani soru kaydedemez. İlk açılış + çevrimdışı
/// senaryosunda kaydetme yolunun kapanmaması buna bağlı. Yedek de aynı
/// kaynaktan üretiliyor, yani "eski bir ağaç" değil "o sürümdeki ağaç".
class CurriculumRepository extends ChangeNotifier {
  CurriculumRepository._();
  static final CurriculumRepository instance = CurriculumRepository._();

  /// Anahtardaki `_v1` ŞEMA sürümü (ağacın kendi sürümü değil): önbellek
  /// biçimi değişirse `_v2` olur ve eski önbellek doğal olarak yok sayılır.
  static const String _kCache = 'curriculum.tree_v1';
  static const String _assetPath = 'assets/curriculum/tree.json';

  /// Sunucudan gelen ağaçlar (müfredat → ağaç).
  final Map<String, CurriculumTree> _fetched = <String, CurriculumTree>{};

  /// Gömülü yedek; yalnızca gerektiğinde okunuyor.
  Map<String, CurriculumTree>? _asset;

  bool _loaded = false;
  bool _refreshing = false;

  /// Önbellek diskten okundu mu (arayüz "hazır mı" diye soruyor).
  bool get isReady => _fetched.isNotEmpty || _asset != null;

  @visibleForTesting
  void resetForTest() {
    _loaded = false;
    _refreshing = false;
    _fetched.clear();
    _asset = null;
  }

  // -------------------------------------------------------------- okuma
  /// [curriculum] için ağaç. Hiçbir kaynak yoksa BOŞ ağaç döner (çökmez).
  CurriculumTree treeFor(String curriculum) =>
      _fetched[curriculum] ??
      _asset?[curriculum] ??
      CurriculumTree.empty;

  /// Önbelleği diskten okur. Ucuz, ağsız ve tekrar çağrılabilir.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_kCache);
      if (raw != null && raw.isNotEmpty) {
        _applyCache(jsonDecode(raw));
      }
    } catch (e, st) {
      // Bozuk önbellek seçiciyi KİLİTLEMESİN: gömülü yedeğe düşülür ve bir
      // sonraki `refresh` tabloyu yeniden yazar. (Yalnız telemetri.)
      unawaited(reportError(e, st, context: 'curriculum.cacheRead'));
    }
    await _ensureAsset();
  }

  /// Gömülü yedeği (bir kez) okur.
  Future<void> _ensureAsset() async {
    if (_asset != null) return;
    try {
      final dynamic doc = jsonDecode(await rootBundle.loadString(_assetPath));
      if (doc is! Map) return;
      final Object? version = doc['version'];
      final Object? curricula = doc['curricula'];
      if (version is! String || curricula is! Map) return;
      _asset = <String, CurriculumTree>{
        for (final MapEntry<dynamic, dynamic> e in curricula.entries)
          e.key as String: CurriculumTree.fromExams(
            version,
            (e.value as Map).cast<String, dynamic>(),
          ),
      };
    } catch (e, st) {
      unawaited(reportError(e, st, context: 'curriculum.assetRead'));
    }
  }

  void _applyCache(dynamic decoded) {
    if (decoded is! Map) return;
    for (final MapEntry<dynamic, dynamic> e in decoded.entries) {
      final Object? v = e.value;
      if (v is! Map) continue;
      final Object? version = v['version'];
      final Object? exams = v['exams'];
      if (version is! String || exams is! Map) continue;
      _fetched[e.key as String] =
          CurriculumTree.fromExams(version, exams.cast<String, dynamic>());
    }
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCache, jsonEncode(<String, dynamic>{
        for (final MapEntry<String, CurriculumTree> e in _fetched.entries)
          e.key: <String, dynamic>{
            'version': e.value.version,
            'exams': <String, dynamic>{
              for (final MapEntry<String, List<SubjectNode>> x
                  in e.value.byExam.entries)
                x.key: <dynamic>[
                  for (final SubjectNode s in x.value)
                    <String, dynamic>{
                      'subject': s.subject,
                      'units': <dynamic>[
                        for (final UnitNode u in s.units)
                          <String, dynamic>{
                            'unit': u.unit,
                            'topics': <dynamic>[
                              for (final TopicNode t in u.topics)
                                <String, dynamic>{
                                  'topic': t.topic,
                                  'aliases': t.aliases,
                                },
                            ],
                          },
                      ],
                    },
                ],
            },
          },
      }));
    } catch (e, st) {
      unawaited(reportError(e, st, context: 'curriculum.cacheWrite'));
    }
  }

  // ------------------------------------------------------------ tazeleme
  /// Sunucudan tazeler.
  ///
  /// Başarısızlık kullanıcıya GÖSTERİLMEZ: eldeki ağaç (önbellek ya da gömülü
  /// yedek) çalışmaya devam ediyor ve konu seçme yolu kapanmıyor.
  Future<void> refresh(String curriculum) async {
    if (_refreshing) return;
    if (!SupabaseConfig.isConfigured) return;
    final SupabaseClient client = Supabase.instance.client;
    if (client.auth.currentUser == null) return;

    _refreshing = true;
    try {
      final String? known = _fetched[curriculum]?.version;
      final dynamic res = await client.rpc<dynamic>(
        'curriculum_tree',
        params: <String, dynamic>{
          'p_curriculum': curriculum,
          'p_known_version': known,
        },
      );
      if (res is! Map) return;
      final Object? version = res['version'];
      if (version is! String || version.isEmpty) return;
      if (res['fresh'] == true && _fetched.containsKey(curriculum)) {
        return; // Değişmemiş: ağaç GÖNDERİLMEDİ, eldeki geçerli.
      }
      final Object? exams = res['exams'];
      if (exams is! Map) return;
      final CurriculumTree tree =
          CurriculumTree.fromExams(version, exams.cast<String, dynamic>());
      if (tree.isEmpty) return; // Boş yanıt eldeki ağacı EZMESİN.
      _fetched[curriculum] = tree;
      await _persist();
      notifyListeners();
    } catch (e, st) {
      unawaited(reportError(e, st, context: 'curriculum.refresh'));
    } finally {
      _refreshing = false;
    }
  }

  /// Sunucunun bildirdiği sürüm elimizdekinden farklıysa tazeler.
  ///
  /// `analyze-question` her yanıtta `taxonomy_version` döndürüyor. Bayat bir
  /// istemci, listede olmayan bir konu gösterip kaydetmeye çalıştığında
  /// `KM022` alırdı — sebebini anlamadığı bir hata. Bu kontrol onay ekranı
  /// AÇILMADAN önce çalışıyor.
  Future<void> refreshIfStale(String curriculum, String? serverVersion) async {
    if (serverVersion == null || serverVersion.isEmpty) return;
    if (_fetched[curriculum]?.version == serverVersion) return;
    await refresh(curriculum);
  }
}

final CurriculumRepository curriculumRepository = CurriculumRepository.instance;
