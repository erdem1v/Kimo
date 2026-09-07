import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';

/// Veri ve gizlilik ekranı (Task 03, bulgu 4.2).
///
/// İki iş görüyor:
///  1. Yurt dışı veri aktarımının (soru fotoğrafı → OpenAI) KALICI olarak
///     okunabileceği yer — tek seferlik onay sayfasına gömülü kalmasın.
///  2. Hukuki metinlerin (KVKK aydınlatma, kullanım koşulları, gizlilik
///     politikası) bağlanacağı yuva. Metinlerin YAZIMI ayrı bir iş kalemi
///     (Task 03 kapsam dışı listesi); yazıldıklarında
///     [_legalSection] yer tutucusunun yerine bağlantılar gelecek.
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
          const SizedBox(height: Gap.xl),
          SectionHeader(title: l.privacyLegalHeading),
          const SizedBox(height: Gap.md),
          KimoCard(
            child: Text(
              l.privacyLegalPlaceholder,
              style: t.body.copyWith(color: c.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
