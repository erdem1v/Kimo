import 'package:flutter/material.dart';

/// Tip A (parametrik/vektörel) soruların şeklini çizen görünüm.
///
/// Şekil, sorunun `drawingParams` alanından okunur ve matematiksel olarak
/// doğru biçimde `CustomPainter` ile çizilir. Diffusion tabanlı görsel üretimi
/// (DALL-E vb.) bilinçli olarak KULLANILMAZ; geometrik tutarlılık şarttır.
///
/// Desteklenen şekiller (MVP):
/// * `triangle`: `points` listesindeki normalize (0–1) köşelerden çokgen.
/// * `circle`: `center` + `radius` (normalize 0–1).
class TipAShapeView extends StatelessWidget {
  const TipAShapeView({super.key, required this.drawingParams});

  final Map<String, dynamic> drawingParams;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: CustomPaint(
        painter: _TipAPainter(
          params: drawingParams,
          strokeColor: scheme.primary,
          labelColor: scheme.onSurface,
          textDirection: Directionality.of(context),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TipAPainter extends CustomPainter {
  _TipAPainter({
    required this.params,
    required this.strokeColor,
    required this.labelColor,
    required this.textDirection,
  });

  final Map<String, dynamic> params;
  final Color strokeColor;
  final Color labelColor;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final String shape = (params['shape'] as String?) ?? 'triangle';
    final Paint stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    switch (shape) {
      case 'circle':
        _paintCircle(canvas, size, stroke);
      case 'triangle':
      default:
        _paintPolygon(canvas, size, stroke);
    }
  }

  Offset _toPixel(num x, num y, Size size) =>
      Offset(x.toDouble() * size.width, y.toDouble() * size.height);

  void _paintPolygon(Canvas canvas, Size size, Paint stroke) {
    final List<dynamic> rawPoints =
        (params['points'] as List<dynamic>?) ?? const <dynamic>[];
    if (rawPoints.length < 2) return;

    final Path path = Path();
    for (int i = 0; i < rawPoints.length; i++) {
      final Map<String, dynamic> p = rawPoints[i] as Map<String, dynamic>;
      final Offset pixel = _toPixel(p['x'] as num, p['y'] as num, size);
      if (i == 0) {
        path.moveTo(pixel.dx, pixel.dy);
      } else {
        path.lineTo(pixel.dx, pixel.dy);
      }
    }
    path.close();
    canvas.drawPath(path, stroke);

    // Köşe etiketleri.
    for (final dynamic raw in rawPoints) {
      final Map<String, dynamic> p = raw as Map<String, dynamic>;
      final String? label = p['label'] as String?;
      if (label == null) continue;
      final Offset pixel = _toPixel(p['x'] as num, p['y'] as num, size);
      _paintLabel(canvas, label, pixel);
    }
  }

  void _paintCircle(Canvas canvas, Size size, Paint stroke) {
    final Map<String, dynamic> center =
        (params['center'] as Map<String, dynamic>?) ??
            <String, dynamic>{'x': 0.5, 'y': 0.5};
    final num radius = (params['radius'] as num?) ?? 0.4;
    final Offset c = _toPixel(center['x'] as num, center['y'] as num, size);
    canvas.drawCircle(c, radius.toDouble() * size.shortestSide, stroke);
  }

  void _paintLabel(Canvas canvas, String text, Offset anchor) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: labelColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: textDirection,
    )..layout();
    // Etiketi köşenin biraz dışına yerleştir.
    tp.paint(canvas, anchor - Offset(tp.width / 2, tp.height + 4));
  }

  @override
  bool shouldRepaint(covariant _TipAPainter oldDelegate) =>
      oldDelegate.params != params ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.labelColor != labelColor;
}
