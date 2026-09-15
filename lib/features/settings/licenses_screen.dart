import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';

/// Açık kaynak lisansları (Task 13).
///
/// NEDEN VAR: uygulama Flutter'ın kendisi, `supabase_flutter`,
/// `google_mobile_ads`, `sentry_flutter`, `flutter_local_notifications`,
/// `url_launcher` ve gömülü **Baloo 2 / DM Sans** yazı tipleri (SIL OFL 1.1)
/// gibi açık kaynak bileşenler taşıyor. Hepsi ATIF gerektiriyor ve depoda
/// bunu gösteren hiçbir yer yoktu.
///
/// NEDEN `showLicensePage` DEĞİL: Flutter'ın hazır sayfası bunu bedavaya
/// veriyor ama Material görünümüyle geliyor — kullanıcı aniden başka bir
/// uygulamaya geçmiş gibi hissediyor. Bu depoda tasarım token'ı dışına çıkan
/// TEK BİR ekran yok ve hazır sayfa o disiplini bozardı. Veri kaynağı aynı
/// ([LicenseRegistry]), yalnızca çizim Kimo'nun kiti ile.
///
/// AKIŞ TEK SEFER OKUNUYOR: `LicenseRegistry.licenses` bir `Stream` ve her
/// dinleyişte paketleri yeniden ayrıştırıyor; liste `initState`te toplanıp
/// durumda tutuluyor.
class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  /// Paket adı → lisans metinleri. Bir paket birden çok lisans taşıyabilir
  /// (ör. ikili lisanslı bağımlılıklar), bir lisans da birden çok pakete ait
  /// olabilir — `LicenseEntry.packages` bu yüzden bir liste.
  final Map<String, List<String>> _byPackage = <String, List<String>>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await for (final LicenseEntry entry in LicenseRegistry.licenses) {
      final String text = entry.paragraphs
          .map((LicenseParagraph p) => p.text.trim())
          .where((String s) => s.isNotEmpty)
          .join('\n\n');
      for (final String package in entry.packages) {
        _byPackage.putIfAbsent(package, () => <String>[]).add(text);
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    final List<String> packages = _byPackage.keys.toList()..sort();

    return Scaffold(
      backgroundColor: c.page,
      appBar: AppBar(
        backgroundColor: c.page,
        surfaceTintColor: Colors.transparent,
        title: Text(l.licensesTitle, style: t.section),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: KimoIcon(KimoIcons.back, color: c.ink),
          tooltip: l.actionBack,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  Gap.screen, Gap.md, Gap.screen, Gap.section),
              children: <Widget>[
                Text(l.licensesIntro,
                    style: t.body.copyWith(color: c.inkSecondary)),
                const SizedBox(height: Gap.lg),
                for (final String package in packages) ...<Widget>[
                  KimoCard(
                    padding: const EdgeInsets.all(Gap.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(package, style: t.bodyStrong),
                        const SizedBox(height: Gap.xs),
                        Text(
                          _byPackage[package]!.join('\n\n---\n\n'),
                          style: t.caption.copyWith(color: c.inkSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Gap.sm),
                ],
              ],
            ),
    );
  }
}
