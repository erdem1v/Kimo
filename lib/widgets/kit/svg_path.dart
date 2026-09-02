import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Küçük bir SVG yol ayrıştırıcısı.
///
/// Neden var: tasarımın ikon dili "1.8–2px kontur, yuvarlak uç, dolgusuz,
/// 24px ızgara" diye tanımlı ve her ikonun yol verisi tasarım dosyasında
/// birebir mevcut. Material ikonları bu geometriye uymuyor (dolgu ağırlıkları
/// ve köşe yarıçapları farklı). Bir SVG paketi eklemek yerine — `pubspec.lock`
/// CI'da kilitli ve çalışma anı ayrıştırma maliyeti gereksiz — yollar bir kez
/// burada [Path]'e çevriliyor.
///
/// Desteklenen komutlar: M m L l H h V v C c S s Q q T t A a Z z.
/// Bu, tasarımdaki bütün ikonları kapsıyor.
Path parseSvgPath(String d) {
  final _PathReader r = _PathReader(d);
  final Path path = Path();

  double cx = 0;
  double cy = 0;
  double sx = 0;
  double sy = 0;
  // Yumuşak eğri komutlarının (S/T) yansıtacağı önceki kontrol noktası.
  double? lastC1x;
  double? lastC1y;
  double? lastQx;
  double? lastQy;
  String previous = '';

  while (r.hasMore) {
    final String cmd = r.readCommand(previous);
    final bool rel = cmd == cmd.toLowerCase();
    final String op = cmd.toUpperCase();

    switch (op) {
      case 'M':
        final double x = r.number() + (rel ? cx : 0);
        final double y = r.number() + (rel ? cy : 0);
        path.moveTo(x, y);
        cx = sx = x;
        cy = sy = y;
        lastC1x = lastQx = null;
      case 'L':
        final double x = r.number() + (rel ? cx : 0);
        final double y = r.number() + (rel ? cy : 0);
        path.lineTo(x, y);
        cx = x;
        cy = y;
        lastC1x = lastQx = null;
      case 'H':
        final double x = r.number() + (rel ? cx : 0);
        path.lineTo(x, cy);
        cx = x;
        lastC1x = lastQx = null;
      case 'V':
        final double y = r.number() + (rel ? cy : 0);
        path.lineTo(cx, y);
        cy = y;
        lastC1x = lastQx = null;
      case 'C':
        final double x1 = r.number() + (rel ? cx : 0);
        final double y1 = r.number() + (rel ? cy : 0);
        final double x2 = r.number() + (rel ? cx : 0);
        final double y2 = r.number() + (rel ? cy : 0);
        final double x = r.number() + (rel ? cx : 0);
        final double y = r.number() + (rel ? cy : 0);
        path.cubicTo(x1, y1, x2, y2, x, y);
        lastC1x = x2;
        lastC1y = y2;
        lastQx = null;
        cx = x;
        cy = y;
      case 'S':
        final double rx = lastC1x == null ? cx : 2 * cx - lastC1x;
        final double ry = lastC1y == null ? cy : 2 * cy - lastC1y;
        final double x2 = r.number() + (rel ? cx : 0);
        final double y2 = r.number() + (rel ? cy : 0);
        final double x = r.number() + (rel ? cx : 0);
        final double y = r.number() + (rel ? cy : 0);
        path.cubicTo(rx, ry, x2, y2, x, y);
        lastC1x = x2;
        lastC1y = y2;
        lastQx = null;
        cx = x;
        cy = y;
      case 'Q':
        final double x1 = r.number() + (rel ? cx : 0);
        final double y1 = r.number() + (rel ? cy : 0);
        final double x = r.number() + (rel ? cx : 0);
        final double y = r.number() + (rel ? cy : 0);
        path.quadraticBezierTo(x1, y1, x, y);
        lastQx = x1;
        lastQy = y1;
        lastC1x = null;
        cx = x;
        cy = y;
      case 'T':
        final double x1 = lastQx == null ? cx : 2 * cx - lastQx;
        final double y1 = lastQy == null ? cy : 2 * cy - lastQy;
        final double x = r.number() + (rel ? cx : 0);
        final double y = r.number() + (rel ? cy : 0);
        path.quadraticBezierTo(x1, y1, x, y);
        lastQx = x1;
        lastQy = y1;
        lastC1x = null;
        cx = x;
        cy = y;
      case 'A':
        final double rx = r.number();
        final double ry = r.number();
        final double rot = r.number();
        final bool largeArc = r.number() != 0;
        final bool sweep = r.number() != 0;
        final double x = r.number() + (rel ? cx : 0);
        final double y = r.number() + (rel ? cy : 0);
        _arcTo(path, cx, cy, x, y, rx, ry, rot, largeArc, sweep);
        lastC1x = lastQx = null;
        cx = x;
        cy = y;
      case 'Z':
        path.close();
        cx = sx;
        cy = sy;
        lastC1x = lastQx = null;
      default:
        throw FormatException('Desteklenmeyen SVG yol komutu: $cmd', d, r.index);
    }
    previous = cmd;
  }
  return path;
}

/// SVG yay komutunu merkez parametrelemesine çevirip kübik Bézier'lerle çizer.
/// Kaynak: SVG 1.1 Ek F.6 (uçtan merkeze dönüşüm).
///
/// `Path.arcTo` yerine Bézier üretiliyor çünkü o API elipsin döndürülmesini
/// (`x-axis-rotation`) desteklemiyor; Bézier yaklaşımı her iki durumu da tek
/// kod yolunda doğru çiziyor.
void _arcTo(
  Path path,
  double x0,
  double y0,
  double x1,
  double y1,
  double rxIn,
  double ryIn,
  double rotationDeg,
  bool largeArc,
  bool sweep,
) {
  if (rxIn == 0 || ryIn == 0 || (x0 == x1 && y0 == y1)) {
    path.lineTo(x1, y1);
    return;
  }
  double rx = rxIn.abs();
  double ry = ryIn.abs();
  final double phi = rotationDeg * math.pi / 180;
  final double cosPhi = math.cos(phi);
  final double sinPhi = math.sin(phi);

  final double dx2 = (x0 - x1) / 2;
  final double dy2 = (y0 - y1) / 2;
  final double x1p = cosPhi * dx2 + sinPhi * dy2;
  final double y1p = -sinPhi * dx2 + cosPhi * dy2;

  // Yarıçaplar noktaları birleştirmeye yetmiyorsa orantılı büyüt (F.6.6).
  final double lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
  if (lambda > 1) {
    final double k = math.sqrt(lambda);
    rx *= k;
    ry *= k;
  }

  final double sign = largeArc == sweep ? -1 : 1;
  final double numerator =
      rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
  final double denominator = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
  final double coef = sign * math.sqrt(math.max(0, numerator / denominator));
  final double cxp = coef * rx * y1p / ry;
  final double cyp = -coef * ry * x1p / rx;

  final double centerX = cosPhi * cxp - sinPhi * cyp + (x0 + x1) / 2;
  final double centerY = sinPhi * cxp + cosPhi * cyp + (y0 + y1) / 2;

  double angleBetween(double ux, double uy, double vx, double vy) {
    final double dot = ux * vx + uy * vy;
    final double len =
        math.sqrt(ux * ux + uy * uy) * math.sqrt(vx * vx + vy * vy);
    double a = math.acos((dot / len).clamp(-1.0, 1.0));
    if (ux * vy - uy * vx < 0) a = -a;
    return a;
  }

  final double ux = (x1p - cxp) / rx;
  final double uy = (y1p - cyp) / ry;
  final double vx = (-x1p - cxp) / rx;
  final double vy = (-y1p - cyp) / ry;
  final double startAngle = angleBetween(1, 0, ux, uy);
  double sweepAngle = angleBetween(ux, uy, vx, vy);
  if (!sweep && sweepAngle > 0) {
    sweepAngle -= 2 * math.pi;
  } else if (sweep && sweepAngle < 0) {
    sweepAngle += 2 * math.pi;
  }

  // Yayı 90 dereceyi geçmeyen parçalara böl: kübik yaklaşımın hatası bu
  // aralıkta göz ardı edilebilir düzeyde kalıyor.
  //
  // Küçük tolerans şart. Tam yarım çemberde `acos` sonucu π'yi 2e-8 kadar
  // aşıyor, oran 2.00000002 çıkıyor ve `ceil` 2 yerine 3 parça üretiyordu.
  // Sonuç yalnızca "bir parça fazla" değil: 60'ar derecelik parçaların kontrol
  // noktaları eksenlerle hizalanmadığı için çemberin sınır kutusu her yönde
  // ~%4 büyüyor ve `Path.getBounds()` yanlış kutu döndürüyordu.
  const double quadrantTolerance = 1e-6;
  final int segments = math.max(
    1,
    (sweepAngle.abs() / (math.pi / 2) - quadrantTolerance).ceil(),
  );
  final double delta = sweepAngle / segments;
  final double alpha = 4 / 3 * math.tan(delta / 4);

  double theta = startAngle;
  for (int i = 0; i < segments; i++) {
    final double cosT = math.cos(theta);
    final double sinT = math.sin(theta);
    final double theta2 = theta + delta;
    final double cosT2 = math.cos(theta2);
    final double sinT2 = math.sin(theta2);

    // Elips üzerindeki nokta ve türevi, dönüş uygulanmış hâlde.
    Offset point(double ct, double st) => Offset(
          centerX + rx * ct * cosPhi - ry * st * sinPhi,
          centerY + rx * ct * sinPhi + ry * st * cosPhi,
        );
    Offset derivative(double ct, double st) => Offset(
          -rx * st * cosPhi - ry * ct * sinPhi,
          -rx * st * sinPhi + ry * ct * cosPhi,
        );

    final Offset p1 = point(cosT, sinT);
    final Offset p2 = point(cosT2, sinT2);
    final Offset d1 = derivative(cosT, sinT);
    final Offset d2 = derivative(cosT2, sinT2);

    path.cubicTo(
      p1.dx + alpha * d1.dx,
      p1.dy + alpha * d1.dy,
      p2.dx - alpha * d2.dx,
      p2.dy - alpha * d2.dy,
      p2.dx,
      p2.dy,
    );
    theta = theta2;
  }
}

class _PathReader {
  _PathReader(this.source);

  final String source;
  int index = 0;

  bool get hasMore {
    _skipSeparators();
    return index < source.length;
  }

  void _skipSeparators() {
    while (index < source.length) {
      final int ch = source.codeUnitAt(index);
      // boşluk, tab, CR, LF, virgül
      if (ch == 0x20 || ch == 0x09 || ch == 0x0D || ch == 0x0A || ch == 0x2C) {
        index++;
      } else {
        break;
      }
    }
  }

  /// Komut harfi okur. Harf yoksa önceki komut tekrarlanır (SVG kuralı:
  /// `M` sonrası örtük `L`, diğerlerinde aynı komut).
  String readCommand(String previous) {
    _skipSeparators();
    final int ch = source.codeUnitAt(index);
    final bool isLetter =
        (ch >= 0x41 && ch <= 0x5A) || (ch >= 0x61 && ch <= 0x7A);
    if (isLetter) {
      index++;
      return source[index - 1];
    }
    if (previous.isEmpty) {
      throw FormatException('SVG yolu komutla başlamalı', source, index);
    }
    if (previous == 'M') return 'L';
    if (previous == 'm') return 'l';
    return previous;
  }

  /// SVG sayı dilbilgisi ayırıcısız yazmaya izin verir: `1.2.8` **iki** sayıdır
  /// (`1.2` ve `.8`), `0-7.2` de öyle. Bu yüzden ikinci ondalık nokta ve
  /// ilk karakterden sonraki işaret sayıyı bitirir — açgözlü okuma burada
  /// sessizce yanlış geometri üretiyordu.
  double number() {
    _skipSeparators();
    final int start = index;
    bool seenDot = false;
    bool seenExponent = false;
    bool seenDigit = false;

    if (index < source.length &&
        (source[index] == '-' || source[index] == '+')) {
      index++;
    }
    while (index < source.length) {
      final int code = source.codeUnitAt(index);
      if (code >= 0x30 && code <= 0x39) {
        seenDigit = true;
        index++;
      } else if (source[index] == '.') {
        if (seenDot || seenExponent) break;
        seenDot = true;
        index++;
      } else if ((source[index] == 'e' || source[index] == 'E') && seenDigit) {
        if (seenExponent) break;
        seenExponent = true;
        index++;
        if (index < source.length &&
            (source[index] == '-' || source[index] == '+')) {
          index++;
        }
      } else {
        break;
      }
    }
    final double? v = double.tryParse(source.substring(start, index));
    if (v == null) {
      throw FormatException('SVG yolunda sayı bekleniyordu', source, start);
    }
    return v;
  }
}
