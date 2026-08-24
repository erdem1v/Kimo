import 'dart:io';
import 'package:image/image.dart' as img;

/// MEBİ breakdown ekran görüntülerini içerik bölgesine kırpıp birkaçını tek
/// kareye dizer; böylece daha az okumayla hepsi görülür.
///   dart run bin/tile_shots.dart "<klasör>" <perTile> "<çıktı-önek>"
Future<void> main(List<String> a) async {
  final Directory dir = Directory(a[0]);
  final int per = a.length > 1 ? int.parse(a[1]) : 4;
  final String prefix = a.length > 2 ? a[2] : 'tile';
  final Directory out = Directory('.kt/tiles')..createSync(recursive: true);

  final List<File> files = dir
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.toLowerCase().endsWith('.jpeg') &&
          !f.path.toLowerCase().contains('konu'))
      .toList()
    ..sort((File x, File y) => x.path.compareTo(y.path));

  final List<img.Image> crops = <img.Image>[];
  for (final File f in files) {
    final img.Image src = img.decodeJpg(f.readAsBytesSync())!;
    // Kenar çubuğunu at (sol ~470px), sağ kenardaki boşluğu bırak.
    final int x0 = (src.width * 0.245).round();
    img.Image c = img.copyCrop(src, x: x0, y: 40,
        width: src.width - x0 - 10, height: src.height - 40);
    c = _trimBottom(c);
    crops.add(c);
  }

  for (int i = 0; i < crops.length; i += per) {
    final List<img.Image> group =
        crops.sublist(i, i + per > crops.length ? crops.length : i + per);
    final int w = group.map((e) => e.width).reduce((a, b) => a > b ? a : b);
    const int gap = 24;
    final int h = group.fold(0, (int s, img.Image e) => s + e.height + gap);
    final img.Image canvas = img.Image(width: w, height: h);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    int y = 0;
    for (final img.Image c in group) {
      img.compositeImage(canvas, c, dstX: 0, dstY: y);
      y += c.height + gap;
    }
    final img.Image scaled = img.copyResize(canvas, width: 1100);
    final String name = '.kt/tiles/${prefix}_${(i ~/ per) + 1}.png';
    File(name).writeAsBytesSync(img.encodePng(scaled, level: 6));
    stdout.writeln('$name  (${group.length} görüntü)');
  }
}

img.Image _trimBottom(img.Image src) {
  int last = src.height - 1;
  while (last > 40 && _blank(src, last)) last--;
  return img.copyCrop(src, x: 0, y: 0, width: src.width,
      height: (last + 20).clamp(1, src.height));
}

bool _blank(img.Image im, int y) {
  int dark = 0;
  final int lim = (im.width * 0.015).ceil();
  for (int x = 0; x < im.width; x += 2) {
    final img.Pixel p = im.getPixel(x, y);
    if (p.r < 210 || p.g < 210 || p.b < 210) {
      if (++dark > lim) return false;
    }
  }
  return true;
}
