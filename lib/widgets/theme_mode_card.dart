import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/sound_service.dart';
import '../state/app_settings.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'kit/kimo_chips.dart';
import 'kit/kimo_surfaces.dart';

/// Tema anahtarı: sistem / açık / koyu.
///
/// İKİ EKRANDA DA GÖRÜNÜYOR (tasarım kararı): en sık değiştirilen tercih,
/// Ayarlar'a girmeden Profil'den de ulaşılabilsin. Ama kod eskiden iki yerde
/// BİREBİR aynı 25 satırdı; kopyaların ayrışması an meselesiydi (bu turda
/// ayrışanların listesi uzun). Tek bileşen, iki çağrı.
class ThemeModeCard extends StatelessWidget {
  const ThemeModeCard({super.key});

  static const List<ThemeMode> _modes = <ThemeMode>[
    ThemeMode.system,
    ThemeMode.light,
    ThemeMode.dark,
  ];

  @override
  Widget build(BuildContext context) {
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    return KimoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.settingsTheme, style: t.bodyStrong),
          const SizedBox(height: Gap.md),
          SegmentedTabs(
            labels: <String>[l.themeSystem, l.themeLight, l.themeDark],
            selectedIndex: _modes.indexOf(appSettings.themeMode),
            onChanged: (int i) {
              sound.tap();
              appSettings.setThemeMode(_modes[i]);
            },
          ),
        ],
      ),
    );
  }
}
