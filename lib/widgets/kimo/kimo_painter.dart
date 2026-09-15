import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../kit/svg_path.dart';
import 'kimo_pose.dart';

/// Kimo'nun sabit renkleri.
///
/// Tema token'ı DEĞİL bilinçli olarak: Kimo bir karakter, açık ve koyu temada
/// aynı görünür. Renkleri temaya bağlamak onu iki farklı karaktere çevirirdi.
/// Değerler tasarımdaki SVG'den birebir alındı.
class KimoPalette {
  const KimoPalette._();

  static const Color earOuter = Color(0xFFB87A45);
  static const Color earInner = Color(0xFFE9A876);
  static const Color head = Color(0xFFC98A4B);
  static const Color muzzle = Color(0xFFF5DCBB);
  static const Color ink = Color(0xFF2A1F16);
  static const Color highlight = Color(0xFFFFFDF9);
  static const Color blush = Color(0x33C2543B);

  // ----------------------------------------------------- persona aksesuarları
  //
  // Tur 7 · n2. Değerler tasarımın SVG'sinden BİREBİR alındı.
  //
  // TEMAYA BAĞLANMADI, yukarıdaki kararın aynısı: Kimo bir karakter ve
  // aksesuarı da karakterin parçası. Aksesuar rengini temaya bağlamak, dört
  // personayı sekiz farklı görünüme çıkarırdı.
  //
  // ADLANDIRILMIŞ olmaları ileriki Rive geçişinin ucuz kalması için: her biri
  // bir Rive renk property'sine 1:1 eşlenebiliyor.

  /// Anaç: kulaktaki çiçek (üç yaprak tonu + göbek) ve örgü.
  static const Color flowerPetal = Color(0xFFF0522F);
  static const Color flowerPetalLight = Color(0xFFFF8A5C);
  static const Color flowerCore = Color(0xFFFFD98A);
  static const Color braidDark = Color(0xFF3A2109);
  static const Color braidMid = Color(0xFF4A2D10);

  /// Lacivert üçlüsü — kasket VE papyon aynı iki tonu paylaşıyor.
  ///
  /// Ayrı `capCrown`/`tieNavy` sabitleri olarak yazılmıştı; ilk görsel test
  /// ikisinin AYNI DEĞER olduğunu gösterdi (#2E5E8A) ve iki ad tek değeri
  /// ikiye ayırmış gibi göstermek, birinin sessizce kaymasına açık kapı
  /// bırakıyordu. Tasarımda da aynı lacivert: iki persona bir renk ailesini
  /// paylaşıyor.
  static const Color navy = Color(0xFF2E5E8A);
  static const Color navyDeep = Color(0xFF24486B);

  /// Yalnızca papyon düğümü — CEO'yu Usta'dan renkle ayıran tek ton.
  static const Color navyKnot = Color(0xFF1B3550);

  /// Arabeskçi: deri ceket yakası ve zincir.
  static const Color jacket = Color(0xFF231E1A);
  static const Color jacketInner = Color(0xFF3E362E);
  static const Color chain = Color(0xFFE6E0D2);
  static const Color medallion = Color(0xFFF2ECDC);
}

/// Kimo'yu çizer. Yalnızca [KimoPose] okur; zaman mantığı burada yok.
///
/// Tasarımın SVG'si `viewBox="52 4 196 200"` ile verilmiş; bütün koordinatlar
/// o uzayda tutuluyor ve tek bir ölçekle widget boyutuna taşınıyor. Böylece
/// ileride Rive varlığı geldiğinde geometri karşılaştırılabilir kalıyor.
class KimoPainter extends CustomPainter {
  KimoPainter({required this.pose, this.accessory = KimoAccessory.none,
      super.repaint});

  final KimoPose pose;

  /// Persona aksesuarı. Taban ayı dört varyantta BİREBİR aynı; değişen tek
  /// şey bu katman (Tur 7 · n2).
  final KimoAccessory accessory;

  // Tasarım uzayı.
  static const double _vbX = 52;
  static const double _vbY = 4;
  static const double _vbW = 196;
  static const double _vbH = 200;

  static const Offset _headCenter = Offset(150, 118);
  static const Offset _leftEar = Offset(96, 44);
  static const Offset _rightEar = Offset(204, 44);
  static const Offset _leftEye = Offset(112, 106);
  static const Offset _rightEye = Offset(188, 106);

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = math.min(size.width / _vbW, size.height / _vbH);
    canvas.save();
    // Tasarım kutusunu widget'ın ortasına yerleştir.
    canvas.translate(
      (size.width - _vbW * scale) / 2,
      (size.height - _vbH * scale) / 2,
    );
    canvas.scale(scale);
    canvas.translate(-_vbX, -_vbY);

    // Gövde dönüşümleri: ölçek TABANDAN uygulanır ki ayaklar zeminde kalsın.
    const Offset feet = Offset(150, 200);
    canvas.save();
    canvas.translate(feet.dx, feet.dy + pose.bodyDy);
    if (pose.bodyRotation != 0) canvas.rotate(pose.bodyRotation);
    canvas.scale(pose.bodyScaleX, pose.bodyScaleY);
    canvas.translate(-feet.dx, -feet.dy);

    _paintEars(canvas);
    _paintHeadGroup(canvas);
    // Aksesuar EN SON ve GÖVDE DÖNÜŞÜMÜNÜN İÇİNDE: tasarımın kuralı
    // "aksesuar katmanı taban dönerken onunla birlikte döner". Bu yüzden her
    // poz ve her tepki için ayrıca bir şey yapmak gerekmiyor — kasket
    // zıplarken de kafada duruyor.
    //
    // Kafa DÖNÜŞÜNÜ paylaşmıyor (o `_paintHeadGroup` içinde kapanıyor):
    // aksesuarların bir kısmı çenenin ALTINDA (yaka, papyon) ve onların kafayla
    // birlikte dönmesi yanlış olurdu.
    _paintAccessory(canvas);

    canvas.restore();
    canvas.restore();
  }

  void _paintEars(Canvas canvas) {
    _ear(canvas, _leftEar, pose.earLeftRotation);
    _ear(canvas, _rightEar, pose.earRightRotation);
  }

  void _ear(Canvas canvas, Offset center, double rotation) {
    // Kulak kendi tabanından döner; taban kafayla birleştiği yer.
    final Offset pivot = Offset(center.dx, center.dy + 26);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(rotation);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawCircle(center, 30, Paint()..color = KimoPalette.earOuter);
    canvas.drawCircle(center, 15, Paint()..color = KimoPalette.earInner);
    canvas.restore();
  }

  void _paintHeadGroup(Canvas canvas) {
    canvas.save();
    if (pose.headRotation != 0) {
      canvas.translate(_headCenter.dx, _headCenter.dy);
      canvas.rotate(pose.headRotation);
      canvas.translate(-_headCenter.dx, -_headCenter.dy);
    }

    // Kafa.
    canvas.drawOval(
      Rect.fromCenter(center: _headCenter, width: 176, height: 156),
      Paint()..color = KimoPalette.head,
    );

    // Ağız bölgesi.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(150, 150), width: 100, height: 74),
      Paint()..color = KimoPalette.muzzle,
    );

    if (pose.blush) {
      final Paint blush = Paint()..color = KimoPalette.blush;
      canvas.drawCircle(const Offset(96, 142), 13, blush);
      canvas.drawCircle(const Offset(204, 142), 13, blush);
    }

    _paintEye(canvas, _leftEye);
    _paintEye(canvas, _rightEye);

    // Burun.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(150, 136), width: 30, height: 22),
      Paint()..color = KimoPalette.ink,
    );

    _paintMouth(canvas);
    canvas.restore();
  }

  void _paintEye(Canvas canvas, Offset center) {
    final Paint ink = Paint()..color = KimoPalette.ink;
    switch (pose.eyes) {
      case KimoEyes.happyArc:
        // Sevinçli yay: yukarı bakan kavis.
        final Paint stroke = Paint()
          ..color = KimoPalette.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        final Path p = Path()
          ..moveTo(center.dx - 11, center.dy + 3)
          ..quadraticBezierTo(center.dx, center.dy - 11, center.dx + 11, center.dy + 3);
        canvas.drawPath(p, stroke);
      case KimoEyes.closedArc:
        final Paint stroke = Paint()
          ..color = KimoPalette.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        final Path p = Path()
          ..moveTo(center.dx - 11, center.dy - 2)
          ..quadraticBezierTo(center.dx, center.dy + 9, center.dx + 11, center.dy - 2);
        canvas.drawPath(p, stroke);
      case KimoEyes.open:
        final double open = pose.eyeOpen.clamp(0.0, 1.0);
        if (open <= 0.02) {
          // Tamamen kapalı: göz kapağı yerine ince bir çizgi.
          canvas.drawLine(
            Offset(center.dx - 9, center.dy),
            Offset(center.dx + 9, center.dy),
            Paint()
              ..color = KimoPalette.ink
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round,
          );
          return;
        }
        final Offset eye = center.translate(pose.pupilDx, pose.pupilDy);
        canvas.save();
        canvas.translate(eye.dx, eye.dy);
        canvas.scale(1, open);
        canvas.translate(-eye.dx, -eye.dy);
        canvas.drawCircle(eye, 11, ink);
        canvas.drawCircle(
          eye.translate(3.5, -4.5),
          3.6,
          Paint()..color = KimoPalette.highlight,
        );
        canvas.restore();
    }
  }

  void _paintMouth(Canvas canvas) {
    final Paint stroke = Paint()
      ..color = KimoPalette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (pose.mouth) {
      case KimoMouth.smile:
        // Tasarımdaki yol: burundan inen çizgi + iki yana açılan kavis.
        final Path p = Path()
          ..moveTo(150, 148)
          ..lineTo(150, 155)
          ..moveTo(150, 155)
          ..cubicTo(143, 155, 139, 151, 139, 147)
          ..moveTo(150, 155)
          ..cubicTo(157, 155, 161, 151, 161, 147);
        canvas.drawPath(p, stroke);
      case KimoMouth.wide:
        final Path p = Path()
          ..moveTo(150, 148)
          ..lineTo(150, 156)
          ..moveTo(150, 156)
          ..cubicTo(139, 156, 133, 150, 133, 145)
          ..moveTo(150, 156)
          ..cubicTo(161, 156, 167, 150, 167, 145);
        canvas.drawPath(p, stroke);
      case KimoMouth.neutral:
        canvas.drawLine(
          const Offset(150, 148),
          const Offset(150, 155),
          stroke,
        );
        canvas.drawLine(
          const Offset(140, 157),
          const Offset(160, 157),
          stroke,
        );
      case KimoMouth.small:
        canvas.drawLine(
          const Offset(150, 148),
          const Offset(150, 152),
          stroke,
        );
        canvas.drawCircle(
          const Offset(150, 158),
          5,
          Paint()
            ..color = KimoPalette.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
    }
  }


  // ======================================================= persona aksesuarı
  //
  // KOORDİNAT UZAYI: aksesuar yolları tasarımın `viewBox="42 6 216 200"`
  // uzayında verildi, painter ise `52 4 196 200` kullanıyor. Dönüşüm
  // GEREKMİYOR ve bu ölçülerek doğrulandı: en dıştaki aksesuar noktaları
  // (örgünün solu x≈57, çiçeğin sağı x≈247, papyonun altı y=200) painter'ın
  // kutusunun İÇİNDE kalıyor. Ayrıca gözler tasarımda (116,108)/(184,108),
  // burada (112,106)/(188,106) — gözlüğün hizası bu yüzden birkaç birim
  // kayıyor ve 30-130 px aralığında görünmüyor.
  //
  // Tek bir adım, iki değil: tasarımın SVG'si de bütün aksesuar katmanlarını
  // tabanın ÜSTÜNE çiziyor. "Yaka çenenin altında kalır" bir Z-SIRASI değil
  // KONUM kuralı — yaka y∈[176,204], ağız bölgesi y≈150, yani üstte çizilse
  // bile çenenin altında duruyor.
  void _paintAccessory(Canvas canvas) {
    switch (accessory) {
      case KimoAccessory.none:
        return;
      case KimoAccessory.anac:
        _paintAnac(canvas);
      case KimoAccessory.usta:
        _paintUsta(canvas);
      case KimoAccessory.ceo:
        _paintCeo(canvas);
      case KimoAccessory.arabeskci:
        _paintArabeskci(canvas);
    }
  }

  /// Anaç: sağ kulakta çiçek, sol kulakta örgü.
  void _paintAnac(Canvas canvas) {
    canvas.drawCircle(const Offset(214, 52), 15,
        Paint()..color = KimoPalette.flowerPetal);
    canvas.drawCircle(const Offset(234, 66), 13,
        Paint()..color = KimoPalette.flowerPetal);
    canvas.drawCircle(const Offset(228, 42), 12,
        Paint()..color = KimoPalette.flowerPetalLight);
    canvas.drawCircle(const Offset(224, 56), 7,
        Paint()..color = KimoPalette.flowerCore);

    _rotatedOval(canvas, const Offset(76, 42), 13, 10, -24,
        KimoPalette.braidDark);
    _rotatedOval(canvas, const Offset(70, 58), 13, 10, 16,
        KimoPalette.braidMid);
    _rotatedOval(canvas, const Offset(74, 74), 12, 9, -16,
        KimoPalette.braidDark);
  }

  /// Sanayi Ustası: kasket (kubbe + siperlik + tepe düğmesi).
  void _paintUsta(Canvas canvas) {
    canvas.drawPath(
      _path('M74 74C80 40 110 22 150 22 190 22 220 40 226 74 198 62 174 56 '
          '150 56 126 56 102 62 74 74Z'),
      Paint()..color = KimoPalette.navy,
    );
    canvas.drawPath(
      _path('M68 72C84 62 108 54 150 54 192 54 216 62 232 72 234 80 228 86 '
          '216 84 188 74 172 70 150 70 128 70 112 74 84 84 72 86 66 80 68 72Z'),
      Paint()..color = KimoPalette.navyDeep,
    );
    canvas.drawCircle(
        const Offset(150, 30), 7, Paint()..color = KimoPalette.navyDeep);
  }

  /// CEO: gözlük (çerçeve [KimoPalette.ink]) + papyon.
  void _paintCeo(Canvas canvas) {
    final Paint frame = Paint()
      ..color = KimoPalette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(96, 92, 42, 32), const Radius.circular(10)),
      frame,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(162, 92, 42, 32), const Radius.circular(10)),
      frame,
    );
    canvas.drawLine(const Offset(138, 104), const Offset(162, 104), frame);

    final Paint navy = Paint()..color = KimoPalette.navy;
    canvas.drawPath(_path('M146 186L120 176L116 200L144 194Z'), navy);
    canvas.drawPath(_path('M154 186L180 176L184 200L156 194Z'), navy);
    final Paint shade = Paint()..color = KimoPalette.navyDeep;
    canvas.drawPath(_path('M120 176L116 200L126 196L128 180Z'), shade);
    canvas.drawPath(_path('M180 176L184 200L174 196L172 180Z'), shade);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(142, 181, 16, 16), const Radius.circular(5)),
      Paint()..color = KimoPalette.navyKnot,
    );
  }

  /// Arabeskçi: deri ceket yakası + zincir. Tasarımda katmanın tamamı
  /// `translate(0,-7)` ile yukarı kaydırılmış.
  void _paintArabeskci(Canvas canvas) {
    canvas.save();
    canvas.translate(0, -7);
    canvas.drawPath(
      _path('M104 184C116 192 132 196 150 196C168 196 184 192 196 184L206 '
          '204H94Z'),
      Paint()..color = KimoPalette.jacket,
    );
    canvas.drawPath(
      _path('M124 188L150 202L176 188L184 192L150 206L116 192Z'),
      Paint()..color = KimoPalette.jacketInner,
    );
    canvas.drawPath(
      _path('M128 186C134 198 142 202 150 202C158 202 166 198 172 186'),
      Paint()
        ..color = KimoPalette.chain
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      _path('M150 196L157 201L150 204L143 201Z'),
      Paint()..color = KimoPalette.medallion,
    );
    canvas.restore();
  }

  /// Kendi merkezinden döndürülmüş elips — tasarımın `rotate(a cx cy)` biçimi.
  void _rotatedOval(Canvas canvas, Offset center, double rx, double ry,
      double degrees, Color color) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(degrees * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      Paint()..color = color,
    );
    canvas.restore();
  }

  /// SVG yol dizgisini [Path]e çevirir.
  ///
  /// Tasarımdan kopyalanan yolları ELLE `Path` çağrılarına dökmek, bir
  /// koordinatın sessizce kayması için en kolay yol olurdu; dizgiyi olduğu gibi
  /// tutmak tasarımla karşılaştırmayı da mümkün kılıyor. Ayrıştırıcı
  /// `lib/widgets/kit/svg_path.dart`'ta ve ikon setinin tamamı onu kullanıyor.
  Path _path(String d) => parseSvgPath(d);

  @override
  bool shouldRepaint(covariant KimoPainter oldDelegate) =>
      oldDelegate.pose != pose || oldDelegate.accessory != accessory;
}
