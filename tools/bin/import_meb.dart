import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'pdf_layout.dart';
import 'supabase_admin.dart';

/// MEB kazanım testlerini soru havuzuna aktarır.
///
///   dart run bin/import_meb.dart manifests/meb_12_matematik.json --dry-run
///   dart run bin/import_meb.dart manifests/meb_12_matematik.json
///
/// --dry-run  : hiçbir şey yüklemez, kesilen soruları out/ altına yazar.
/// --only 3,7 : yalnızca bu testleri işler (manifestteki sıra numarası).
///
/// Yükleme için ortam değişkenleri gerekir (bkz. tools/README.md):
///   SUPABASE_URL, SUPABASE_SERVICE_KEY
/// Konu ağacı — ÜRETİLEN varlıktan okunuyor (`assets/curriculum/tree.json`).
///
/// Task 09'a kadar burada elle yazılmış 12 ders adı vardı: ağacın DÖRDÜNCÜ
/// kopyası. Bozuk kodlanmış bir ders adı ("CoÄŸrafya") havuza sessizce girip
/// görünmez soru yığını bırakmıştı; kontrol o yüzden vardı ama listeyi elle
/// tutmak aynı sınıf hatayı başka bir yerde üretiyordu.
///
/// KONU DA ARTIK DOĞRULANIYOR. Eskiden yalnızca `subject` bakılıyordu;
/// manifestteki MEB etiketi (`Destek ve Hareket Sistemi`) ham hâliyle
/// veritabanına giriyor ve `tools/remap_konu.sql` ELLE çalıştırılana kadar
/// haritada hiçbir konuya düşmüyordu. O betik artık yok: etiketler ağacın
/// kendisinde (`eski:`) ve burada çözülüyor.
class _Taxonomy {
  _Taxonomy(this._topics, this._aliases);

  /// `'<sınav>|<ders>'` -> kanonik konu adları
  final Map<String, Set<String>> _topics;

  /// `'<sınav>|<ders>'` -> normalize etiket -> kanonik konu
  final Map<String, Map<String, String>> _aliases;

  Set<String> get subjects => <String>{
        for (final String k in _topics.keys) k.split('|')[1],
      };

  /// Kanonik adı döndürür; ağaçta karşılığı yoksa null.
  String? resolve(String exam, String subject, String concept) {
    final String key = '$exam|$subject';
    final String norm = _norm(concept);
    for (final String t in _topics[key] ?? const <String>{}) {
      if (_norm(t) == norm) return t;
    }
    return _aliases[key]?[norm];
  }

  /// `public.tr_norm` ve `tools/build_taxonomy.py` ile AYNI sonucu vermeli.
  static String _norm(String v) {
    const String from = 'ÇĞİÖŞÜÂÎÛçğıöşüâîû';
    const String to = 'CGIOSUAIUcgiosuaiu';
    final StringBuffer out = StringBuffer();
    for (final int r in v.runes) {
      final int i = from.runes.toList().indexOf(r);
      out.writeCharCode(i >= 0 ? to.codeUnitAt(i) : r);
    }
    return out.toString().toLowerCase().split(RegExp(r'\s+')).where(
          (String s) => s.isNotEmpty,
        ).join(' ');
  }

  /// MEB soruları eski müfredattan; ağacın o dalı okunuyor.
  static _Taxonomy load(String root) {
    final File f = File('$root/assets/curriculum/tree.json');
    if (!f.existsSync()) {
      stderr.writeln('Konu agaci bulunamadi: ${f.path}\n'
          'Once `python3 tools/build_taxonomy.py` calistirin.');
      exit(66);
    }
    final Map<String, dynamic> doc =
        (jsonDecode(f.readAsStringSync()) as Map).cast<String, dynamic>();
    final Map<String, dynamic> eski =
        ((doc['curricula'] as Map)['eski'] as Map).cast<String, dynamic>();

    final Map<String, Set<String>> topics = <String, Set<String>>{};
    final Map<String, Map<String, String>> aliases =
        <String, Map<String, String>>{};
    for (final String exam in <String>['TYT', 'AYT']) {
      for (final dynamic sRaw in (eski[exam] as List<dynamic>? ?? <dynamic>[])) {
        final Map<String, dynamic> s = (sRaw as Map).cast<String, dynamic>();
        final String key = '$exam|${s['subject']}';
        for (final dynamic uRaw in (s['units'] as List<dynamic>)) {
          final Map<String, dynamic> u = (uRaw as Map).cast<String, dynamic>();
          for (final dynamic tRaw in (u['topics'] as List<dynamic>)) {
            final Map<String, dynamic> t = (tRaw as Map).cast<String, dynamic>();
            final String topic = t['topic'] as String;
            (topics[key] ??= <String>{}).add(topic);
            for (final dynamic a in (t['aliases'] as List<dynamic>)) {
              (aliases[key] ??= <String, String>{})[_norm(a as String)] = topic;
            }
          }
        }
      }
    }
    return _Taxonomy(topics, aliases);
  }
}

// Sayfa 200 dpi taranır (kesim koordinatları o çözünürlükte isabetli), sonra
// çıktı 150 dpi'ye indirilir. Testler siyah-beyaz çizim ve metin olduğu için
// 4 renkli paletli PNG, JPEG'den ~5 kat küçük çıkıyor ve daha temiz görünür.
// Gri tonu bol bir görsel (fotoğraf) gelirse palet onu bozar; hata eşiği
// aşılınca JPEG'e düşülür.
const int _dpi = 200;
const double _outScale = 0.75;
const int _paletteColors = 4;
const double _maxPaletteError = 12;
const int _jpegQuality = 75;

Future<void> main(List<String> args) async {
  final List<String> positional = args
      .where((String a) => !a.startsWith('--'))
      .toList();
  if (positional.isEmpty) {
    stderr.writeln(
      'Kullanım: dart run bin/import_meb.dart <manifest.json> '
      '[--dry-run] [--only 1,2]',
    );
    exit(64);
  }
  final bool dryRun = args.contains('--dry-run');
  final Set<int>? only = _onlyFilter(args);

  // Aynı konu adı birden çok manifestte geçiyor (11. ve 12. sınıfın
  // "Roman" testleri gibi); dosya adları çakışmasın diye her set kendi
  // klasörüne yazılır.
  final String setName = File(
    positional.first,
  ).uri.pathSegments.last.replaceAll('.json', '');
  final Map<String, dynamic> manifest =
      jsonDecode(await File(positional.first).readAsString())
          as Map<String, dynamic>;
  final List<dynamic> tests = manifest['tests'] as List<dynamic>;

  // Ağaç depo kökünden okunuyor. Bu betik `tools/` içinden çalıştırılıyor
  // (bkz. tools/README.md), yani kök bir üst dizin.
  final _Taxonomy taxonomy = _Taxonomy.load(
    Directory.current.path.endsWith('tools') ? '..' : '.',
  );

  SupabaseAdmin? admin;
  if (dryRun) {
    stdout.writeln('KURU ÇALIŞMA — hiçbir şey yüklenmeyecek.');
  } else {
    admin = await SupabaseAdmin.fromEnv();
    stdout.writeln('Havuz hesabı: ${admin.ownerId}');
  }

  final Directory cache = Directory('.cache')..createSync(recursive: true);
  final Directory out = Directory('out')..createSync(recursive: true);

  int okCount = 0;
  int skipCount = 0;
  final List<String> problems = <String>[];

  for (int i = 0; i < tests.length; i++) {
    final Map<String, dynamic> t = (tests[i] as Map).cast<String, dynamic>();
    final int no = i + 1;
    if (only != null && !only.contains(no)) continue;

    final String subject = t['subject'] as String;
    if (!taxonomy.subjects.contains(subject)) {
      stderr.writeln(
        'Bilinmeyen ders adi: "$subject" (test $no). '
        'Manifest bozuk — taxonomy/yks-konulari.md ile ayni olmali.',
      );
      exit(65);
    }
    final String url = t['url'] as String;
    final String rawConcept = t['concept'] as String;
    final String? resolved =
        taxonomy.resolve(t['exam'] as String, subject, rawConcept);
    if (resolved == null) {
      // DURUYOR, atlamıyor: sessizce gecen bir konu adi, havuzda hicbir
      // konuya dusmeyen gorunmez sorular birakiyordu.
      stderr.writeln(
        'Konu agacinda karsiligi yok: "$rawConcept" '
        '(${t['exam']} · $subject, test $no).\n'
        'Ya manifesti duzeltin ya da taxonomy/yks-konulari.md icinde ilgili '
        'konuya `eski: $rawConcept` etiketi ekleyip ureticiyi calistirin.',
      );
      exit(65);
    }
    final String concept = resolved;
    final String answers = (t['answers'] as String)
        .replaceAll(RegExp(r'\s'), '')
        .toUpperCase();
    final String label = '#$no ${t['subject']} · $concept';

    // Kazanım kavrama kitaplarında tek PDF onlarca test taşıyor; testin
    // sayfa aralığı manifestte verilir. Yoksa dosyanın tamamı bir testtir.
    final List<dynamic>? range = t['pages'] as List<dynamic>?;
    final int? fromPage = range == null ? null : range.first as int;
    final int? toPage = range == null ? null : range.last as int;

    try {
      final File pdf = await _download(url, cache);
      final List<PageLayout> pages = await layoutOf(
        pdf.path,
        from: fromPage,
        to: toPage,
      );

      // Soru kutuları: sayfa sayfa çıkar, sonra numaraya göre birleştir.
      final List<QuestionBox> boxes = <QuestionBox>[];
      for (int p = 0; p < pages.length; p++) {
        boxes.addAll(boxesForPage(pages[p], p + 1));
      }
      boxes.sort(
        (QuestionBox a, QuestionBox b) => a.number.compareTo(b.number),
      );

      // Doğrulama: numaralar 1..N olarak eksiksiz çıkmalı ve cevap anahtarıyla
      // aynı sayıda olmalı. Tutmuyorsa elle bakılmalı — sessizce yarısını
      // yüklemek, havuza bozuk soru sokmaktan beterdir.
      final String numbers = boxes.map((QuestionBox b) => b.number).join(',');
      final String expected = List<int>.generate(
        answers.length,
        (int k) => k + 1,
      ).join(',');
      if (numbers != expected) {
        problems.add(
          '$label -> soru numaraları beklenenden farklı\n'
          '      beklenen: $expected\n      bulunan : $numbers',
        );
        skipCount++;
        continue;
      }

      final List<img.Image> rendered = await _renderPages(
        pdf,
        pages.length,
        from: fromPage,
        to: toPage,
      );

      for (final QuestionBox box in boxes) {
        final img.Image crop = _crop(rendered[box.page - 1], box);
        final ({List<int> bytes, String ext}) enc = _encode(crop);
        final String name =
            '$setName/${_slug(concept)}-$no-${box.number}.${enc.ext}';

        if (dryRun) {
          File('${out.path}/$name')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(enc.bytes);
        } else {
          await admin!.publishQuestion(
            bytes: enc.bytes,
            contentType: enc.ext == 'png' ? 'image/png' : 'image/jpeg',
            fileName: name,
            exam: t['exam'] as String,
            subject: subject,
            concept: concept,
            correctIndex: _indexOf(answers[box.number - 1]),
            source: manifest['source'] as String,
            sourceYear: manifest['sourceYear'] as int?,
            sourceSession: manifest['sourceSession'] as String?,
          );
        }
      }
      okCount += boxes.length;
      stdout.writeln('OK  $label — ${boxes.length} soru');
    } catch (e) {
      problems.add('$label -> $e');
      skipCount++;
    }
  }

  stdout.writeln('\n──────────────');
  stdout.writeln('İşlenen soru : $okCount');
  stdout.writeln('Atlanan test : $skipCount');
  if (dryRun) stdout.writeln('Kesimler     : ${out.absolute.path}');
  if (problems.isNotEmpty) {
    stdout.writeln('\nElle bakılacaklar:');
    for (final String p in problems) {
      stdout.writeln('  - $p');
    }
  }
}

Set<int>? _onlyFilter(List<String> args) {
  final int i = args.indexOf('--only');
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1]
      .split(',')
      .map((String s) => int.tryParse(s.trim()))
      .whereType<int>()
      .toSet();
}

int _indexOf(String letter) {
  const String letters = 'ABCDE';
  final int i = letters.indexOf(letter);
  if (i < 0) throw Exception('Geçersiz cevap harfi: $letter');
  return i;
}

/// PDF'i indirir; aynı dosya ikinci kez indirilmez.
Future<File> _download(String url, Directory cache) async {
  final File f = File('${cache.path}/${_hash(url)}.pdf');
  if (f.existsSync() && f.lengthSync() > 0) return f;
  final http.Response r = await http.get(Uri.parse(url));
  if (r.statusCode != 200) {
    throw Exception('PDF indirilemedi (${r.statusCode})');
  }
  f.writeAsBytesSync(r.bodyBytes);
  return f;
}

/// Sayfaları PNG'ye çevirir (pdftoppm) ve belleğe alır.
Future<List<img.Image>> _renderPages(
  File pdf,
  int pageCount, {
  int? from,
  int? to,
}) async {
  final Directory tmp = Directory.systemTemp.createTempSync('mebpdf');
  try {
    final ProcessResult r = await Process.run('pdftoppm', <String>[
      '-r',
      '$_dpi',
      '-png',
      if (from != null) ...<String>['-f', '$from'],
      if (to != null) ...<String>['-l', '$to'],
      pdf.path,
      '${tmp.path}/p',
    ]);
    if (r.exitCode != 0) {
      throw Exception('pdftoppm başarısız (${r.exitCode}): ${r.stderr}');
    }
    final List<File> files =
        tmp
            .listSync()
            .whereType<File>()
            .where((File f) => f.path.endsWith('.png'))
            .toList()
          ..sort((File a, File b) => a.path.compareTo(b.path));
    if (files.length != pageCount) {
      throw Exception('Sayfa sayısı tutmuyor: ${files.length} != $pageCount');
    }
    return <img.Image>[
      for (final File f in files) img.decodePng(f.readAsBytesSync())!,
    ];
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

/// PDF puntosundan piksele çevirip keser, alttaki boşluğu kırpar.
img.Image _crop(img.Image page, QuestionBox box) {
  const double scale = _dpi / 72;
  int px(double pt) => (pt * scale).round();
  final int x = px(box.left).clamp(0, page.width - 1);
  final int y = px(box.top).clamp(0, page.height - 1);
  final int w = (px(box.right) - x).clamp(1, page.width - x);
  final int h = (px(box.bottom) - y).clamp(1, page.height - y);
  final img.Image cut = img.copyCrop(page, x: x, y: y, width: w, height: h);
  return _trimBottom(cut);
}

/// Sorular sayfaya yayıldığı için altta geniş boşluk kalıyor; kırp.
img.Image _trimBottom(img.Image src) {
  int last = src.height - 1;
  while (last > 20 && _rowIsBlank(src, last)) {
    last--;
  }
  final int h = (last + 12).clamp(1, src.height);
  return img.copyCrop(src, x: 0, y: 0, width: src.width, height: h);
}

/// "Neredeyse boş" satır. Tam beyaz aramak yetmiyor: sayfanın altındaki süs
/// şeridinin ince çizgileri birkaç piksel bırakıp kırpmayı durduruyordu.
bool _rowIsBlank(img.Image im, int y) {
  int dark = 0;
  final int limit = (im.width * 0.01).ceil();
  for (int x = 0; x < im.width; x++) {
    final img.Pixel p = im.getPixel(x, y);
    if (p.r < 230 || p.g < 230 || p.b < 230) {
      if (++dark > limit) return false;
    }
  }
  return true;
}

/// Kesimi kodlar. Metin/çizim ise paletli PNG, gri tonu bol ise JPEG.
({List<int> bytes, String ext}) _encode(img.Image crop) {
  final img.Image gray = img.grayscale(crop);
  final img.Image small = img.copyResize(
    gray,
    width: (gray.width * _outScale).round(),
    interpolation: img.Interpolation.average,
  );
  final img.Image quant = img.quantize(
    small.clone(),
    numberOfColors: _paletteColors,
  );
  if (_meanError(small, quant) <= _maxPaletteError) {
    return (bytes: img.encodePng(quant, level: 9), ext: 'png');
  }
  return (bytes: img.encodeJpg(small, quality: _jpegQuality), ext: 'jpg');
}

/// İki görüntü arasındaki ortalama parlaklık farkı (0-255).
double _meanError(img.Image a, img.Image b) {
  int sum = 0;
  int n = 0;
  // Her pikseli gezmek gereksiz; 3'er atlamak yeterince temsili.
  for (int y = 0; y < a.height; y += 3) {
    for (int x = 0; x < a.width; x += 3) {
      sum += (a.getPixel(x, y).luminance - b.getPixel(x, y).luminance)
          .abs()
          .round();
      n++;
    }
  }
  return n == 0 ? 0 : sum / n;
}

String _slug(String s) {
  const Map<String, String> tr = <String, String>{
    'â': 'a',
    'î': 'i',
    'û': 'u',
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
    'Â': 'a',
    'Î': 'i',
    'Û': 'u',
    'Ç': 'c',
    'Ğ': 'g',
    'İ': 'i',
    'Ö': 'o',
    'Ş': 's',
    'Ü': 'u',
  };
  final String ascii = s.split('').map((String c) => tr[c] ?? c).join();
  return ascii
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

String _hash(String s) {
  int h = 0x811c9dc5;
  for (final int c in utf8.encode(s)) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}
