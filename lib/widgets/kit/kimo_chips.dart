import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Seçilebilir çip (ders, sınav, hata türü).
class KimoChip extends StatelessWidget {
  const KimoChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.press,
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.ink : c.sunken,
          borderRadius: Radii.all(Radii.chip),
        ),
        child: Text(
          label,
          style: t.bodyStrong.copyWith(
            color: selected ? c.page : c.inkSecondary,
          ),
        ),
      ),
    );
  }
}

/// Durum rozetinin anlamı. Renk tek taşıyıcı değildir: her rozet metinle
/// birlikte verilir, renk körlüğünde bilgi kaybı olmaz.
enum BadgeTone {
  /// Israrlı yanlış — mercan.
  alert,

  /// Hâkim olunan — nane.
  mastered,

  /// Bugün tekrar / bekleyen — bal.
  pending,

  /// Nötr bilgi — oyuk zemin.
  neutral,
}

/// Küçük durum etiketi: "HÂKİM", "İNATÇI · 4×", "KUYRUKTA · ÇEVRİMDIŞI".
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone});

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final (Color bg, Color fg) = switch (tone) {
      BadgeTone.alert => (c.actionTintStrong, c.actionTextStrong),
      BadgeTone.mastered => (c.mintTint, c.mintText),
      BadgeTone.pending => (c.honeyTint, c.honeyText),
      BadgeTone.neutral => (c.sunken, c.inkSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: Radii.all(Radii.chip),
      ),
      child: Text(
        label,
        style: t.overline.copyWith(color: fg),
      ),
    );
  }
}

/// İki ya da daha fazla seçenekli segment — TYT/AYT, Lig/Arkadaşlar.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.sunken,
        borderRadius: Radii.all(Radii.pill),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: Motion.press,
                  padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? c.card : Colors.transparent,
                    borderRadius: Radii.all(Radii.chip),
                    boxShadow: i == selectedIndex
                        ? <BoxShadow>[
                            BoxShadow(
                              color: c.cardShadow,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: t.section.copyWith(
                      fontSize: 14.5,
                      color: i == selectedIndex ? c.ink : c.inkSecondary,
                      fontWeight: i == selectedIndex
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
