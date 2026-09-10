/// Konu ağacının istemci tarafındaki biçimi ve araması.
///
/// **Veri burada DEĞİL.** Ağaç sunucudan geliyor (`curriculum_tree` RPC) ve
/// diske önbelleğe alınıyor; ilk açılış/çevrimdışı için `assets/curriculum/
/// tree.json` gömülü yedeği var. İkisi de `taxonomy/yks-konulari.md`
/// kaynağından üretiliyor.
///
/// Task 09'a kadar aynı ağaç `lib/data/yks_curriculum.dart` içinde elle
/// yazılıydı ve `analyze-question/taxonomy.ts` ikinci bir kopyasını taşıyordu.
/// Senkronu garanti eden tek şey bir yorum satırıydı.
library;

/// Türkçe duyarlı arama normalizasyonu.
///
/// SQL'deki `public.tr_norm` ve `tools/build_taxonomy.py`'deki `tr_norm` ile
/// AYNI sonucu vermek ZORUNDA. Ayrışırlarsa kullanıcının yazdığı kelime
/// sunucunun bulduğuyla eşleşmez — ve bu sessizce olur.
///
/// Sıra önemli: önce Türkçe harfler ASCII'ye çevriliyor, sonra küçültülüyor.
/// Ters sırada `'İ'.toLowerCase()` iki kod noktası üretir ve eşleşme kaçar.
String trNorm(String value) {
  const String from = 'ÇĞİÖŞÜÂÎÛçğıöşüâîû';
  const String to = 'CGIOSUAIUcgiosuaiu';
  final StringBuffer out = StringBuffer();
  for (final int rune in value.runes) {
    final int i = from.runes.toList().indexOf(rune);
    out.writeCharCode(i >= 0 ? to.codeUnitAt(i) : rune);
  }
  return out.toString().toLowerCase().split(RegExp(r'\s+')).where(
        (String s) => s.isNotEmpty,
      ).join(' ');
}

/// Ağacın yaprağı. [aliases] yalnızca ARAMA içindir; kaydedilen değer her
/// zaman [topic]'tir.
class TopicNode {
  const TopicNode({required this.topic, this.aliases = const <String>[]});

  final String topic;
  final List<String> aliases;

  factory TopicNode.fromJson(Map<String, dynamic> json) => TopicNode(
        topic: (json['topic'] as String?) ?? '',
        aliases: <String>[
          for (final dynamic a in (json['aliases'] as List<dynamic>? ??
              const <dynamic>[]))
            a as String,
        ],
      );
}

/// Ünite — yalnızca GRUPLAMA için. Kayıtta yeri yok.
class UnitNode {
  const UnitNode({required this.unit, required this.topics});

  final String unit;
  final List<TopicNode> topics;

  factory UnitNode.fromJson(Map<String, dynamic> json) => UnitNode(
        unit: (json['unit'] as String?) ?? '',
        topics: <TopicNode>[
          for (final dynamic t in (json['topics'] as List<dynamic>? ??
              const <dynamic>[]))
            TopicNode.fromJson((t as Map).cast<String, dynamic>()),
        ],
      );
}

class SubjectNode {
  const SubjectNode({required this.subject, required this.units});

  final String subject;
  final List<UnitNode> units;

  factory SubjectNode.fromJson(Map<String, dynamic> json) => SubjectNode(
        subject: (json['subject'] as String?) ?? '',
        units: <UnitNode>[
          for (final dynamic u in (json['units'] as List<dynamic>? ??
              const <dynamic>[]))
            UnitNode.fromJson((u as Map).cast<String, dynamic>()),
        ],
      );
}

/// Arama sonucu. [matchedAlias] doluysa eşleşme konu adından değil bir
/// ETİKETTEN geldi; arayüz bunu gösteriyor ki kullanıcı neden bu sonucu
/// gördüğünü ve neyin kaydedileceğini anlasın.
class TopicHit {
  const TopicHit({
    required this.subject,
    required this.unit,
    required this.topic,
    this.matchedAlias,
  });

  final String subject;
  final String unit;
  final String topic;
  final String? matchedAlias;
}

/// Tek bir müfredatın (eski | maarif) ağacı.
class CurriculumTree {
  const CurriculumTree({required this.version, required this.byExam});

  final String version;

  /// 'TYT' | 'AYT' → dersler (ağaçtaki sırayla).
  final Map<String, List<SubjectNode>> byExam;

  static const CurriculumTree empty =
      CurriculumTree(version: '', byExam: <String, List<SubjectNode>>{});

  bool get isEmpty => byExam.values.every((List<SubjectNode> s) => s.isEmpty);

  /// Sunucunun `exams` nesnesi ve gömülü varlığın müfredat girdisi AYNI
  /// biçimde; tek ayrıştırıcı ikisine de yetiyor.
  factory CurriculumTree.fromExams(String version, Map<String, dynamic> exams) {
    return CurriculumTree(
      version: version,
      byExam: <String, List<SubjectNode>>{
        for (final String exam in <String>['TYT', 'AYT'])
          exam: <SubjectNode>[
            for (final dynamic s in (exams[exam] as List<dynamic>? ??
                const <dynamic>[]))
              SubjectNode.fromJson((s as Map).cast<String, dynamic>()),
          ],
      },
    );
  }

  List<SubjectNode> subjectsOf(String exam) =>
      byExam[exam] ?? const <SubjectNode>[];

  List<String> subjectNames(String exam) =>
      <String>[for (final SubjectNode s in subjectsOf(exam)) s.subject];

  List<UnitNode> unitsOf(String exam, String subject) {
    for (final SubjectNode s in subjectsOf(exam)) {
      if (s.subject == subject) return s.units;
    }
    return const <UnitNode>[];
  }

  /// Sunucudaki `is_valid_topic` ile AYNI kararı vermeli: aynı ağaç, birebir ad.
  bool isValidTopic(String exam, String subject, String topic) {
    for (final UnitNode u in unitsOf(exam, subject)) {
      for (final TopicNode t in u.topics) {
        if (t.topic == topic) return true;
      }
    }
    return false;
  }

  /// O sınavın TÜM derslerinde arar.
  ///
  /// Task 09'a kadar arama yalnızca SEÇİLİ dersin içindeydi ve normalizasyon
  /// yoktu: "ucgen" yazan kullanıcı "Üçgenler"i bulamıyor, Fizik seçmemişse
  /// "atışlar" hiç sonuç vermiyordu. Onlarca ders ve yüzlerce konu varken iç
  /// içe menü gezmek gerçek bir maliyet.
  ///
  /// Sıralama: tam eşleşme > kelime başı > içerir; her kademede konu adı
  /// etiketten önce, eşitlikte [preferSubject] önce, sonra ağaç sırası.
  List<TopicHit> search(
    String exam,
    String query, {
    String? preferSubject,
    int limit = 60,
  }) {
    final String q = trNorm(query);
    if (q.isEmpty) return const <TopicHit>[];

    final List<_Scored> hits = <_Scored>[];
    int order = 0;
    for (final SubjectNode s in subjectsOf(exam)) {
      final bool preferred = s.subject == preferSubject;
      for (final UnitNode u in s.units) {
        final String unitNorm = trNorm(u.unit);
        for (final TopicNode t in u.topics) {
          order++;
          final int? direct = _score(trNorm(t.topic), q);
          int? best = direct == null ? null : direct * 2;
          String? alias;
          for (final String a in t.aliases) {
            final int? sc = _score(trNorm(a), q);
            if (sc == null) continue;
            final int weighted = sc * 2 + 1; // konu adı etiketten önce
            if (best == null || weighted < best) {
              best = weighted;
              alias = a;
            }
          }
          if (best == null && unitNorm.contains(q)) {
            best = 9; // ünite eşleşmesi en zayıf sinyal
          }
          if (best == null) continue;
          hits.add(_Scored(
            score: best,
            preferred: preferred ? 0 : 1,
            order: order,
            hit: TopicHit(
              subject: s.subject,
              unit: u.unit,
              topic: t.topic,
              matchedAlias: alias,
            ),
          ));
        }
      }
    }

    hits.sort((_Scored a, _Scored b) {
      final int byScore = a.score.compareTo(b.score);
      if (byScore != 0) return byScore;
      final int byPref = a.preferred.compareTo(b.preferred);
      if (byPref != 0) return byPref;
      return a.order.compareTo(b.order);
    });
    return <TopicHit>[
      for (final _Scored s in hits.take(limit)) s.hit,
    ];
  }

  /// 0 = tam eşleşme, 1 = kelime başı, 2 = içerir, null = eşleşmiyor.
  static int? _score(String value, String q) {
    if (value == q) return 0;
    if (value.startsWith(q)) return 1;
    if (value.contains(' $q')) return 1;
    if (value.contains(q)) return 2;
    return null;
  }
}

class _Scored {
  const _Scored({
    required this.score,
    required this.preferred,
    required this.order,
    required this.hit,
  });

  final int score;
  final int preferred;
  final int order;
  final TopicHit hit;
}
