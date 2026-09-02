import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Bugün ekranındaki dilimli çember.
///
/// Sürekli bir yay değil, ayrı ayrı dilimler: kaç soru kaldığı bir bakışta
/// sayılabiliyor. Hedef bir sınır değil; dolduktan sonra ekstra tur açılır,
/// bu yüzden [filled] [total] değerini aşabilir ve çember tamamen dolu kalır.
class SegmentRing extends StatelessWidget {
  const SegmentRing({
    super.key,
    required this.total,
    required this.filled,
    required this.size,
    this.child,
    this.filledColor,
    this.emptyColor,
  });

  /// Dilim sayısı (tasarımda 20).
  final int total;

  /// Dolu dilim sayısı.
  final int filled;

  final double size;

  /// Çemberin göbeğinde duran içerik (sayaç, maskot).
  final Widget? child;

  final Color? filledColor;
  final Color? emptyColor;

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SegmentRingPainter(
          total: math.max(total, 1),
          filled: filled.clamp(0, math.max(total, 1)),
          filledColor: filledColor ?? c.action,
          emptyColor: emptyColor ?? c.trackEmpty,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _SegmentRingPainter extends CustomPainter {
  _SegmentRingPainter({
    required this.total,
    required this.filled,
    required this.filledColor,
    required this.emptyColor,
  });

  final int total;
  final int filled;
  final Color filledColor;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Tasarım 100 birimlik bir kutuda çizilmiş; oranlar korunuyor.
    final double scale = size.shortestSide / 100;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double inner = 34.5 * scale;
    final double outer = 43.5 * scale;
    final Paint paint = Paint()
      ..strokeWidth = 7.4 * scale
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double step = 2 * math.pi / total;
    for (int i = 0; i < total; i++) {
      // Saat 12'den başla, saat yönünde ilerle.
      final double angle = -math.pi / 2 + i * step;
      final Offset dir = Offset(math.cos(angle), math.sin(angle));
      paint.color = i < filled ? filledColor : emptyColor;
      canvas.drawLine(center + dir * inner, center + dir * outer, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentRingPainter oldDelegate) =>
      oldDelegate.total != total ||
      oldDelegate.filled != filled ||
      oldDelegate.filledColor != filledColor ||
      oldDelegate.emptyColor != emptyColor;
}

/// Yatay ilerleme çubuğu (pratik ekranının üst şeridi, seviye şeridi).
class KimoProgressBar extends StatelessWidget {
  const KimoProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.color,
    this.trackColor,
  });

  /// 0–1 arası. Aşan değerler kırpılır.
  final double value;
  final double height;
  final Color? color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: ColoredBox(color: trackColor ?? c.sunken),
            ),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: AnimatedContainer(
                duration: Motion.fill,
                curve: Motion.fillCurve,
                decoration: BoxDecoration(
                  color: color ?? c.action,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// HUD hapı: ikon + sayı. Seri, can ve elmas göstergeleri bunu kullanır.
class HudPill extends StatelessWidget {
  const HudPill({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    this.value,
    this.child,
    this.onTap,
    this.semanticLabel,
  });

  final Widget icon;
  final Color background;
  final Color foreground;

  /// Sağda görünen sayı. [child] verilirse yok sayılır.
  final String? value;

  /// Sayı yerine özel içerik (ör. can kalpleri + "yarın yenilenir").
  final Widget? child;

  final VoidCallback? onTap;

  /// Ekran okuyucu için tam cümle — "12 günlük seri" gibi.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final KimoTypography t = context.t;
    final Widget body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: Gap.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: Radii.all(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconTheme(
            data: IconThemeData(color: foreground, size: 16),
            child: icon,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: child ??
                Text(
                  value ?? '',
                  style: t.numberSmall.copyWith(color: foreground),
                ),
          ),
        ],
      ),
    );

    // Bilerek `Expanded` DÖNDÜRMÜYOR: satırdaki payı çağıran belirler
    // (tasarımda 1 / 1.5 / 1). Widget'ın kendini Flex'e mecbur bırakması
    // onu Row dışında kullanılamaz hâle getirirdi.
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: onTap == null
          ? body
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: body,
            ),
    );
  }
}
