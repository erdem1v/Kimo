import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/mascot.dart';
import '../../services/sound_service.dart';
import '../../state/user_profile.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kimo/kimo.dart';
import '../../widgets/kimo/kimo_pose.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';

/// Kimo'nun karakteri — ayarlardan açılır.
///
/// Karakter Kimo'nun YÜZÜNÜ değiştirmiyor; rengini ve bildirimlerdeki sesini
/// belirliyor. Bu yüzden satırlarda emoji yok: her satır Kimo'nun o karakterle
/// aldığı rengi gösteriyor.
Future<void> showMascotSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.c.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (BuildContext ctx) => const _MascotSheet(),
  );
}

class _MascotSheet extends StatefulWidget {
  const _MascotSheet();

  @override
  State<_MascotSheet> createState() => _MascotSheetState();
}

class _MascotSheetState extends State<_MascotSheet> {
  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            Gap.screen, Gap.lg, Gap.screen, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: Radii.all(2),
                ),
              ),
            ),
            const SizedBox(height: Gap.lg),
            Text(l.mascotStepTitle, style: t.section),
            const SizedBox(height: Gap.xxs),
            Text(
              l.mascotStepBody,
              style: t.caption.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: Gap.lg),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final Mascot m in Mascot.values) ...<Widget>[
                    _tile(context, m),
                    const SizedBox(height: Gap.sm),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Mascot m) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final bool selected = userProfile.mascot == m;
    return KimoCard(
      padding: const EdgeInsets.all(Gap.md),
      radius: Radii.tile,
      elevated: selected,
      color: selected ? c.actionTint : c.sunken,
      onTap: () async {
        sound.tap();
        await userProfile.setMascot(m);
        if (mounted) Navigator.of(context).pop();
      },
      child: Row(
        children: <Widget>[
          Kimo(size: 40, mood: selected ? KimoMood.happy : null),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  m.label,
                  style: selected
                      ? t.label.copyWith(color: c.actionText)
                      : t.label,
                ),
                const SizedBox(height: Gap.xxs),
                Text(
                  m.tagline,
                  style: t.caption.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
          if (selected)
            KimoIcon(KimoIcons.check, size: 20, color: c.actionText),
        ],
      ),
    );
  }
}
