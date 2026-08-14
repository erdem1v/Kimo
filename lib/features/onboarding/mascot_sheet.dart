import 'package:flutter/material.dart';

import '../../models/mascot.dart';
import '../../services/sound_service.dart';
import '../../state/user_profile.dart';
import '../../theme/app_colors.dart';

/// Maskot (koç karakteri) değiştirme alt sayfası — profilden açılır.
Future<void> showMascotSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Koçun kim olsun?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Bildirimleri ve motivasyon sözlerini o yazar.',
              style: TextStyle(color: AppColors.inkLight, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final Mascot m in Mascot.values) _tile(m),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(Mascot m) {
    final bool selected = userProfile.mascot == m;
    return GestureDetector(
      onTap: () async {
        sound.tap();
        await userProfile.setMascot(m);
        if (mounted) Navigator.of(context).pop();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? m.color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? m.color : AppColors.line,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: m.color.withValues(alpha: selected ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(m.emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    m.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: selected ? m.color : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.tagline,
                    style: const TextStyle(
                      color: AppColors.inkLight,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: m.color, size: 22),
          ],
        ),
      ),
    );
  }
}
