import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';


class _Stroke {
  _Stroke({required this.isEraser, required this.width});
  final bool isEraser;
  final double width;
  final List<Offset> points = <Offset>[];
}

/// Soru fotoğrafının üstünde iki modlu çalışma alanı:
/// * **Dokunma (varsayılan):** parmakla yakınlaştır/kaydır (InteractiveViewer).
/// * **Kalem / Silgi:** üstüne çizim; çizimler soruya sabittir, zoom'la ölçeklenir.
/// Arka plan olarak [background] (soru fotoğrafı) verilir.
class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({super.key, this.background});

  final Widget? background;

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  static const Color _penColor = Color(0xFF2563EB);

  final List<_Stroke> _strokes = <_Stroke>[];
  final TransformationController _tc = TransformationController();
  bool _drawMode = false; // false = dokunma/zoom
  bool _eraser = false;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _start(Offset p) {
    final _Stroke s = _Stroke(isEraser: _eraser, width: _eraser ? 28 : 3.5);
    s.points.add(p);
    setState(() => _strokes.add(s));
  }

  void _extend(Offset p) {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.last.points.add(p));
  }

  void _undo() {
    if (_strokes.isNotEmpty) setState(() => _strokes.removeLast());
  }

  void _clear() {
    if (_strokes.isNotEmpty) setState(_strokes.clear);
  }

  void _resetZoom() => _tc.value = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    return Column(
      children: <Widget>[
        _toolbar(context),
        const SizedBox(height: Gap.sm),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: Radii.all(Radii.tile),
              border: Border.all(color: c.border, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InteractiveViewer(
              transformationController: _tc,
              panEnabled: !_drawMode,
              scaleEnabled: !_drawMode,
              minScale: 1,
              maxScale: 5,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (widget.background != null)
                    Positioned.fill(child: widget.background!),
                  Positioned.fill(
                    child: _drawMode
                        ? GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (DragStartDetails d) =>
                                _start(d.localPosition),
                            onPanUpdate: (DragUpdateDetails d) =>
                                _extend(d.localPosition),
                            child: CustomPaint(
                              painter: _CanvasPainter(_strokes, _penColor),
                              child: const SizedBox.expand(),
                            ),
                          )
                        : IgnorePointer(
                            child: CustomPaint(
                              painter: _CanvasPainter(_strokes, _penColor),
                              child: const SizedBox.expand(),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolbar(BuildContext context) {
    final KimoColors c = context.c;
    return Row(
      children: <Widget>[
        _modeButton(context, Icons.pan_tool_rounded, 'Dokunma', !_drawMode, () {
          setState(() => _drawMode = false);
        }),
        const SizedBox(width: 6),
        _modeButton(context, Icons.edit, 'Kalem', _drawMode && !_eraser, () {
          setState(() {
            _drawMode = true;
            _eraser = false;
          });
        }),
        const SizedBox(width: 6),
        _modeButton(context, Icons.auto_fix_normal, 'Silgi', _drawMode && _eraser, () {
          setState(() {
            _drawMode = true;
            _eraser = true;
          });
        }),
        const Spacer(),
        IconButton(
          onPressed: _strokes.isEmpty ? null : _undo,
          icon: const Icon(Icons.undo_rounded),
          color: c.inkMuted,
          tooltip: 'Geri al',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: _strokes.isEmpty ? null : _clear,
          icon: const Icon(Icons.delete_outline_rounded),
          color: c.inkMuted,
          tooltip: 'Temizle',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: _resetZoom,
          icon: const Icon(Icons.center_focus_strong_rounded),
          color: c.inkMuted,
          tooltip: 'Yakınlaştırmayı sıfırla',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _modeButton(BuildContext context,
      IconData icon, String label, bool active, VoidCallback onTap) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.mintTint : c.sunken,
          borderRadius: Radii.all(Radii.pill),
          border: Border.all(
            color: active ? c.mint : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 17,
                color: active ? c.mintText : c.inkMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: t.captionStrong.copyWith(
                color: active ? c.mintText : c.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  _CanvasPainter(this.strokes, this.penColor);

  final List<_Stroke> strokes;
  final Color penColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final _Stroke s in strokes) {
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = s.isEraser ? const Color(0xFF000000) : penColor
        ..blendMode = s.isEraser ? BlendMode.clear : BlendMode.srcOver;
      if (s.points.length < 2) {
        canvas.drawCircle(
          s.points.first,
          s.width / 2,
          Paint()
            ..color = paint.color
            ..blendMode = paint.blendMode,
        );
      } else {
        final Path path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
        for (int i = 1; i < s.points.length; i++) {
          path.lineTo(s.points[i].dx, s.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CanvasPainter oldDelegate) => true;
}
