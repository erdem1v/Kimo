import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/mascot.dart';
import '../../services/crash_service.dart';
import '../../services/sound_service.dart';
import '../../state/user_profile.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'persona_card.dart';

/// Kimo'nun sesi — ayarlardan açılır.
///
/// Karşılama akışındaki adımla **aynı kartı** kullanıyor: iki yerde iki farklı
/// düzen, kullanıcının orada öğrendiği karşılaştırmayı burada yeniden
/// öğrenmesini gerektirirdi. Fark yalnızca çerçeve — burada kilit ekranı
/// önizlemesi yok, çünkü kullanıcı bildirimleri zaten görmüş oluyor.
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

class _MascotSheet extends StatelessWidget {
  const _MascotSheet();

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(Gap.screen, Gap.lg, Gap.screen, Gap.lg),
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
            Text(l.mascotStepBody, style: t.caption.copyWith(color: c.inkMuted)),
            const SizedBox(height: Gap.lg),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final Mascot m in Mascot.values) ...<Widget>[
                    PersonaCard(
                      mascot: m,
                      selected: userProfile.mascot == m,
                      onTap: () => _choose(context, m),
                    ),
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

  /// Seçimi kaydeder ve **beklemeden** kapanır.
  ///
  /// `setMascot` artık üç ağ çağrısı yapıyor (auth metadata, `profiles` satırı,
  /// metin önbelleği). Eskiden sheet bunların bitmesini bekliyordu ve yavaş
  /// ağda göstergesiz asılı kalıyordu — dokunuşun sonucu görünmüyordu.
  /// Yazma başarısız olursa kullanıcı bunu bilmeli: hata 1. kovada (görünür).
  void _choose(BuildContext context, Mascot m) {
    final NavigatorState nav = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String failed = L10n.of(context).onboardSaveFailed;
    sound.tap();
    nav.pop();
    unawaited(() async {
      try {
        await userProfile.setMascot(m);
      } catch (e, st) {
        messenger.showSnackBar(SnackBar(content: Text(failed)));
        unawaited(reportError(e, st, context: 'profile.setMascot'));
      }
    }());
  }
}
