import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/legal_links.dart';
import '../../services/sound_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';

/// Veri ve gizlilik ekranı (Task 03, bulgu 4.2 · Task 07, bulgu A-6).
///
/// İki iş görüyor:
///  1. Yurt dışı veri aktarımının (soru fotoğrafı → OpenAI) KALICI olarak
///     okunabileceği yer — tek seferlik onay sayfasına gömülü kalmasın.
///  2. Hukuki metinlerin bağlantıları.
///
/// **Task 07: "hazırlanıyor" yer tutucusu kaldırıldı.** Mağaza incelemesinde
/// doğrudan sorulan şey oydu (App Store Connect ve Play Console gizlilik
/// politikası bağlantısını zorunlu tutuyor). Adresler derleme zamanında
/// `--dart-define` ile geliyor ([LegalLinks]); verilmemiş bir adresin satırı
/// HİÇ ÇİZİLMİYOR — kırık bir bağlantı göstermek, göstermemekten kötü.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);

    return Scaffold(
      backgroundColor: c.page,
      appBar: AppBar(
        backgroundColor: c.page,
        surfaceTintColor: Colors.transparent,
        title: Text(l.privacyTitle, style: t.section),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: KimoIcon(KimoIcons.back, color: c.ink),
          tooltip: l.actionBack,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Gap.screen, Gap.md, Gap.screen, Gap.section),
        children: <Widget>[
          SectionHeader(title: l.privacyAiHeading),
          const SizedBox(height: Gap.md),
          KimoCard(child: Text(l.privacyAiBody, style: t.body)),
          if (LegalLinks.anyConfigured) ...<Widget>[
            const SizedBox(height: Gap.xl),
            SectionHeader(title: l.privacyLegalHeading),
            const SizedBox(height: Gap.md),
            Text(
              l.privacyLegalIntro,
              style: t.caption.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: Gap.md),
            _link(context, l, l.privacyTermsLink, LegalLinks.terms),
            _link(context, l, l.privacyPrivacyLink, LegalLinks.privacy),
            _link(context, l, l.privacyKvkkLink, LegalLinks.kvkk),
            _link(context, l, l.privacyDeletionLink, LegalLinks.accountDeletion),
          ],
        ],
      ),
    );
  }

  Widget _link(BuildContext context, L10n l, String label, String url) {
    if (!LegalLinks.has(url)) return const SizedBox.shrink();
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: KimoCard(
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg, vertical: Gap.md),
        radius: Radii.tile,
        onTap: () async {
          sound.tap();
          final bool ok = await openLegalUrl(url);
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l.privacyLinkFailed)));
          }
        },
        // Ayarlar listesindeki `_row` ile aynı görsel dil: baştaki kilit,
        // sondaki yön işareti.
        child: Row(
          children: <Widget>[
            KimoIcon(KimoIcons.lock, size: 20, color: c.inkMuted),
            const SizedBox(width: Gap.md),
            Expanded(child: Text(label, style: t.label)),
            const SizedBox(width: Gap.sm),
            KimoIcon(KimoIcons.forward, size: 16, color: c.border),
          ],
        ),
      ),
    );
  }
}
