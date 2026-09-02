import 'dart:math' as math;

import 'package:flutter/widgets.dart';

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
}

/// Kimo'yu çizer. Yalnızca [KimoPose] okur; zaman mantığı burada yok.
///
/// Tasarımın SVG'si `viewBox="52 4 196 200"` ile verilmiş; bütün koordinatlar
/// o uzayda tutuluyor ve tek bir ölçekle widget boyutuna taşınıyor. Böylece
/// ileride Rive varlığı geldiğinde geometri karşılaştırılabilir kalıyor.
class KimoPainter extends CustomPainter {
  KimoPainter({required this.pose, super.repaint});

  final KimoPose pose;

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

  @override
  bool shouldRepaint(covariant KimoPainter oldDelegate) =>
      oldDelegate.pose != pose;
}
