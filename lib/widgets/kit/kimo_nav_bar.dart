import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'kimo_icons.dart';

/// Alt sekme çubuğundaki bir sekme.
@immutable
class KimoNavItem {
  const KimoNavItem({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  final KimoIconData icon;
  final String label;

  /// Sıfırdan büyükse rozet gösterilir (gelen kutusu, arkadaş isteği).
  final int badgeCount;
}

/// Bugün · Hatalarım · (kamera) · Lig · Profil.
///
/// Kamera düğmesi çubuğun 12px üstüne taşar ama **taşan kısım da tıklanır**:
/// düğme `Transform` ile kaydırılmıyor, satırın yüksekliği 12px artırılıp
/// sekmeler alta hizalanıyor. Kaydırma yaklaşımında üst 12px isabet testine
/// girmiyordu.
class KimoNavBar extends StatelessWidget {
  const KimoNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onCapture,
    required this.captureLabel,
  });

  /// Tam olarak dört sekme; ortadaki kamera bunlardan biri değil.
  final List<KimoNavItem> items;

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCapture;

  /// Kamera düğmesinin erişilebilirlik etiketi.
  final String captureLabel;

  static const double _rise = 12;
  static const double _rowHeight = Sizes.rowMin + _rise;

  @override
  Widget build(BuildContext context) {
    assert(items.length == 4, 'Alt çubuk dört sekme + kamera olarak tasarlandı');
    final KimoColors c = context.c;

    return Container(
      color: c.navBar,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(
            left: Gap.xs,
            right: Gap.xs,
            top: Gap.xs,
            bottom: Gap.xs,
          ),
          child: SizedBox(
            height: _rowHeight,
            child: Row(
              children: <Widget>[
                Expanded(child: _tab(context, 0)),
                Expanded(child: _tab(context, 1)),
                SizedBox(width: 70, child: _captureButton(context)),
                Expanded(child: _tab(context, 2)),
                Expanded(child: _tab(context, 3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int index) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final KimoNavItem item = items[index];
    final bool active = index == selectedIndex;
    final Color color = active ? c.navActive : c.navIdle;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Semantics(
        button: true,
        selected: active,
        label: item.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(index),
          child: SizedBox(
            height: Sizes.rowMin,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    KimoIcon(
                      item.icon,
                      color: color,
                      strokeWidth: active ? 2.6 : 2,
                    ),
                    if (item.badgeCount > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: _Badge(count: item.badgeCount),
                      ),
                  ],
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.tabLabel.copyWith(
                    color: color,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _captureButton(BuildContext context) {
    final KimoColors c = context.c;
    return Align(
      alignment: Alignment.topCenter,
      child: Semantics(
        button: true,
        label: captureLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onCapture,
          child: Container(
            width: Sizes.cameraButton,
            height: Sizes.cameraButton,
            decoration: BoxDecoration(
              color: c.cameraButton,
              borderRadius: Radii.all(Radii.button),
              boxShadow: <BoxShadow>[
                BoxShadow(color: c.cameraShadow, offset: const Offset(0, 5)),
              ],
            ),
            alignment: Alignment.center,
            child: KimoIcon(KimoIcons.camera, size: 25, color: c.cameraIcon),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.actionTextStrong,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: t.captionStrong.copyWith(color: c.onAction, fontSize: 11),
      ),
    );
  }
}
