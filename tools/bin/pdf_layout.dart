import 'dart:math';
import 'dart:io';

/// PDF'ten çıkarılan bir kelimenin yeri (birim: PDF puntosu, 1/72 inç).
class Word {
  const Word(this.text, this.xMin, this.yMin, this.xMax, this.yMax);

  final String text;
  final double xMin;
  final double yMin;
  final double xMax;
  final double yMax;

  double get height => yMax - yMin;
}

/// Bir PDF sayfası: boyutu ve içindeki kelimeler.
class PageLayout {
  PageLayout(this.width, this.height, this.words);

  final double width;
  final double height;
  final List<Word> words;
}

/// Bir sorunun sayfadaki dikdörtgeni (PDF puntosu).
class QuestionBox {
  const QuestionBox({
    required this.number,
    required this.page,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int number;
  final int page; // 1'den başlar
  final double left;
  final double top;
  final double right;
  final double bottom;

  @override
  String toString() =>
      '#$number s$page '
      '(${left.toStringAsFixed(0)},${top.toStringAsFixed(0)})-'
      '(${right.toStringAsFixed(0)},${bottom.toStringAsFixed(0)})';
}

final RegExp _pageRe = RegExp(
  r'<page width="([\d.]+)" height="([\d.]+)"',
  multiLine: true,
);
final RegExp _wordRe = RegExp(
  r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)">(.*?)</word>',
);
final RegExp _numberRe = RegExp(r'^(\d{1,2})\.$');

/// `pdftotext -bbox` çıktısını sayfalara ayırır.
///
/// Türkçe harfler bu PDF'lerde bozuk çıkıyor (yazı tipinin Unicode eşlemesi
/// eksik) ama KOORDİNATLAR sağlam — kesim için tek ihtiyacımız o. Soru
/// numaraları da ASCII olduğu için sorunsuz okunuyor.
List<PageLayout> parseBBox(String xml) {
  final List<PageLayout> pages = <PageLayout>[];
  final List<Match> starts = _pageRe.allMatches(xml).toList();
  for (int i = 0; i < starts.length; i++) {
    final int from = starts[i].end;
    final int to = i + 1 < starts.length ? starts[i + 1].start : xml.length;
    final String body = xml.substring(from, to);
    final List<Word> words = <Word>[
      for (final Match m in _wordRe.allMatches(body))
        Word(
          m.group(5)!.trim(),
          double.parse(m.group(1)!),
          double.parse(m.group(2)!),
          double.parse(m.group(3)!),
          double.parse(m.group(4)!),
        ),
    ];
    pages.add(
      PageLayout(
        double.parse(starts[i].group(1)!),
        double.parse(starts[i].group(2)!),
        words,
      ),
    );
  }
  return pages;
}

/// Sayfadaki soruları bulur ve her birinin dikdörtgenini çıkarır.
///
/// Yöntem: soru numaraları ("1.", "2.") sütunun en solunda, tek başına durur.
/// Numaraların yerini biliyorsak kesim çizgileri de bellidir — bir sonraki
/// numaranın hemen üstü. Sayfa başlığındaki "12. Sınıf" gibi yazılar sağda
/// kaldığı için elenir.
List<QuestionBox> boxesForPage(PageLayout page, int pageNo) {
  final List<Word> numbers = page.words
      .where(
        (Word w) =>
            _numberRe.hasMatch(w.text) &&
            w.yMin > 60 && // üstteki başlık şeridi
            w.xMin < page.width * 0.6,
      ) // sağdaki "12. Sınıf" başlığı
      .toList();
  if (numbers.isEmpty) return const <QuestionBox>[];

  final double mid = page.width / 2;
  final List<Word> leftNums = _numberColumn(
    numbers.where((Word w) => w.xMin < mid).toList(),
  );
  final List<Word> rightNums = _numberColumn(
    numbers.where((Word w) => w.xMin >= mid).toList(),
  );

  final double leftX = leftNums.isEmpty ? 14 : leftNums.first.xMin;
  final double rightX = rightNums.isEmpty ? mid + 10 : rightNums.first.xMin;

  final List<QuestionBox> boxes = <QuestionBox>[];
  boxes.addAll(
    _column(page, pageNo, leftNums, leftX - 6, _gutter(page, rightX)),
  );
  boxes.addAll(_column(page, pageNo, rightNums, rightX - 6, page.width - 8));
  boxes.sort((QuestionBox a, QuestionBox b) => a.number.compareTo(b.number));
  return boxes;
}

/// Bir sütundaki gerçek soru numaralarını seçer.
///
/// Soru metninin içinde de "5." ya da "80." gibi ifadeler geçebiliyor; bunlar
/// numara sanılırsa kesim yanlış yerden bölünür. Gerçek numaralar tek bir
/// hizada dizilir, en kalabalık küme onlardır.
///
/// MEB testlerinde hizalama tek tip değil: bazı testlerde numaralar sola
/// (xMin sabit, "10." daha geniş), bazılarında sağa hizalı ("10." daha solda
/// başlar, noktalar aynı yerde biter). Bu yüzden iki kenara göre de kümeleyip
/// daha kalabalık olanı alıyoruz — yoksa hizalamalardan biri hep bozuluyor.
List<Word> _numberColumn(List<Word> candidates) {
  if (candidates.length < 2) return candidates;

  // Hem sol hem sağ kenara göre kümele; hangisinin doğru olduğunu hizalama
  // belirlesin diye ikisinin de bütün kümeleri havuza girer.
  final List<List<Word>> groups = <List<Word>>[
    ..._clusters(candidates, (Word w) => w.xMin),
    ..._clusters(candidates, (Word w) => w.xMax),
  ];

  // Tek başına duran sayılar (şekil etiketleri) elenir; hiçbiri çoklu değilse
  // elimizde ne varsa onunla devam ederiz.
  final List<List<Word>> multi = groups
      .where((List<Word> g) => g.length >= 2)
      .toList();
  final List<List<Word>> pool = multi.isEmpty ? groups : multi;

  // Kazanan EN SOLDAKİ kümedir, en kalabalık olan değil: soru numarası sütunun
  // başında durur, sorunun içindeki "I. II. III." listeleri daha sağdadır ve
  // kimi zaman onlardan daha çok olur.
  pool.sort((List<Word> a, List<Word> b) {
    final int byEdge = _leftEdge(a).compareTo(_leftEdge(b));
    return byEdge != 0 ? byEdge : b.length.compareTo(a.length);
  });

  // Kazanan küme seçildikten sonra hizası biraz kayan numaraları geri al:
  // MEB sayfalarında tek tük soru numarası birkaç punto içeride/dışarıda
  // başlıyor ve dar toleransla kümenin dışında kalıyordu. Uzaktaki şekil
  // etiketleri bu pencereye giremez, sıra kuralı da ayrıca süzer.
  final List<Word> best = _widen(pool.first, candidates)
    ..sort((Word a, Word b) => a.yMin.compareTo(b.yMin));
  return _increasingOnly(best);
}

List<Word> _widen(List<Word> chosen, List<Word> all) {
  const double window = 8;
  final double lo = chosen.map((Word w) => w.xMin).reduce(min);
  final double hi = chosen.map((Word w) => w.xMax).reduce(max);
  return all
      .where(
        (Word w) =>
            chosen.contains(w) ||
            (w.xMin - lo).abs() <= window ||
            (w.xMax - hi).abs() <= window,
      )
      .toList();
}

double _leftEdge(List<Word> ws) =>
    ws.map((Word w) => w.xMin).reduce((double a, double b) => a < b ? a : b);

/// Numaralar sayfada yukarıdan aşağı ARTAR. Bu sırayı bozanları atar: şekil
/// içindeki etiketler ve tekrar eden numaralar böylece elenir.
List<Word> _increasingOnly(List<Word> sortedByY) {
  final List<Word> kept = <Word>[];
  int last = 0;
  for (final Word w in sortedByY) {
    final int n = int.parse(_numberRe.firstMatch(w.text)!.group(1)!);
    if (n > last) {
      kept.add(w);
      last = n;
    }
  }
  return kept;
}

/// [key] değerine göre yakın duran kelimeleri kümeler (tolerans 2.5 punto).
List<List<Word>> _clusters(List<Word> words, double Function(Word) key) {
  final List<Word> sorted = words.toList()
    ..sort((Word a, Word b) => key(a).compareTo(key(b)));
  final List<List<Word>> out = <List<Word>>[];
  List<Word> run = <Word>[sorted.first];
  for (int i = 1; i < sorted.length; i++) {
    if (key(sorted[i]) - key(run.last) <= 2.5) {
      run.add(sorted[i]);
    } else {
      out.add(run);
      run = <Word>[sorted[i]];
    }
  }
  out.add(run);
  return out;
}

/// İki sütun arasındaki oluk: sayfanın ortasında, yan yazılmış MEB künyesinin
/// durduğu şerit. Künye kesime sızarsa hem görüntüyü kirletir hem de alttaki
/// boşluk kırpmasını bozar (o satırlar "boş" sayılmaz).
///
/// Künye kelimeleri tek bir x'te üst üste dizilir; gerçek metinde böyle bir
/// yığın olmaz. En az üç kelimelik böyle bir yığın bulursak sol sütunu onun
/// hemen solunda kesiyoruz.
double _gutter(PageLayout page, double rightX) {
  // Yalnızca oluğa bak: sağ sütunun hemen solundaki dar şerit. Daha geniş
  // arasak sıkların (A, B, C...) hizası da bir yığın gibi görünür ve kesimi
  // sütunun ortasından biçerdik.
  final Map<int, int> stack = <int, int>{};
  for (final Word w in page.words) {
    if (w.xMin > rightX - 30 && w.xMin < rightX - 2) {
      stack.update(w.xMin.round(), (int n) => n + 1, ifAbsent: () => 1);
    }
  }
  final List<int> found =
      stack.entries
          .where((MapEntry<int, int> e) => e.value >= 3)
          .map((MapEntry<int, int> e) => e.key)
          .toList()
        ..sort();
  return found.isEmpty ? rightX - 14 : found.first - 3;
}

List<QuestionBox> _column(
  PageLayout page,
  int pageNo,
  List<Word> nums,
  double left,
  double maxRight,
) {
  if (nums.isEmpty) return const <QuestionBox>[];

  // Sütuna ait kelimeler: soldan ve sağdan sınır içinde, ilk sorunun
  // hizasından aşağıda olanlar. Üstteki konu şeridi böylece dışarıda kalır.
  final List<Word> own = page.words
      .where(
        (Word w) =>
            w.xMin >= left - 2 &&
            w.xMax <= maxRight &&
            w.yMin >= nums.first.yMin - 4,
      )
      .toList();

  double reduce(
    double Function(double, double) f,
    double seed,
    double Function(Word) get,
  ) => own.isEmpty ? seed : own.map(get).reduce(f);

  final double right =
      (reduce(
                (double a, double b) => a > b ? a : b,
                maxRight,
                (Word w) => w.xMax,
              ) +
              6)
          .clamp(left + 20, maxRight);
  final double contentBottom = reduce(
    (double a, double b) => a > b ? a : b,
    page.height - 60,
    (Word w) => w.yMax,
  );

  return <QuestionBox>[
    for (int i = 0; i < nums.length; i++)
      QuestionBox(
        number: int.parse(_numberRe.firstMatch(nums[i].text)!.group(1)!),
        page: pageNo,
        left: left,
        top: nums[i].yMin - 8,
        right: right,
        bottom: i + 1 < nums.length ? nums[i + 1].yMin - 8 : contentBottom + 4,
      ),
  ];
}

/// `pdftotext -bbox` çalıştırır. [from]/[to] verilirse yalnızca o sayfalar
/// okunur — kazanım kavrama kitapları tek PDF'te onlarca test taşıyor.
Future<List<PageLayout>> layoutOf(String pdfPath, {int? from, int? to}) async {
  final ProcessResult r = await Process.run('pdftotext', <String>[
    '-bbox',
    if (from != null) ...<String>['-f', '$from'],
    if (to != null) ...<String>['-l', '$to'],
    pdfPath,
    '-',
  ], stdoutEncoding: SystemEncoding());
  if (r.exitCode != 0) {
    throw Exception('pdftotext başarısız (${r.exitCode}): ${r.stderr}');
  }
  return parseBBox(r.stdout as String);
}
