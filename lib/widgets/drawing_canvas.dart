import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class _Stroke {
  _Stroke({required this.isEraser, required this.width});
  final bool isEraser;
  final double width;
  final List<Offset> points = <Offset>[];
}

/// Soru fotoğrafının ÜSTÜNE çizim yapılan katman: kalem + silgi + geri al +
/// temizle. Arka plan olarak [background] (genellikle soru fotoğrafı) verilir;
/// silgi gerçek siler (mürekkebi kaldırır, altındaki soru görünür).
class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({super.key, this.background});

  final Widget? background;

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  static const Color _penColor = Color(0xFF2563EB); // beyaz kağıtta belirgin mavi

  final List<_Stroke> _strokes = <_Stroke>[];
  bool _eraser = false;

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _toolbar(),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: <Widget>[
                if (widget.background != null)
                  Positioned.fill(child: widget.background!),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (DragStartDetails d) => _start(d.localPosition),
                    onPanUpdate: (DragUpdateDetails d) => _extend(d.localPosition),
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
      ],
    );
  }

  Widget _toolbar() {
    return Row(
      children: <Widget>[
        _toolChip(Icons.edit, 'Kalem', !_eraser, () => setState(() => _eraser = false)),
        const SizedBox(width: 8),
        _toolChip(Icons.auto_fix_normal, 'Silgi', _eraser, () => setState(() => _eraser = true)),
        const Spacer(),
        IconButton(
          onPressed: _strokes.isEmpty ? null : _undo,
          icon: const Icon(Icons.undo_rounded),
          color: AppColors.inkLight,
          tooltip: 'Geri al',
        ),
        IconButton(
          onPressed: _strokes.isEmpty ? null : _clear,
          icon: const Icon(Icons.delete_outline_rounded),
          color: AppColors.inkLight,
          tooltip: 'Temizle',
        ),
      ],
    );
  }

  Widget _toolChip(IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.green.withValues(alpha: 0.14)
              : const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.green : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon,
                size: 18,
                color: active ? AppColors.greenDark : AppColors.inkLight),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.greenDark : AppColors.inkLight,
                fontWeight: FontWeight.w700,
                fontSize: 13,
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
    // Mürekkep katmanını izole et ki silgi (BlendMode.clear) yalnızca çizimi
    // silsin, altındaki fotoğrafı değil.
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
        final Path path = Path()
          ..moveTo(s.points.first.dx, s.points.first.dy);
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
