import 'package:flutter/material.dart';

import '../../data/notification_lines.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/mascot.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kimo/kimo.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';

/// Örnek bildirimlerdeki kurgusal seri uzunluğu. Sayı, çevrilecek bir metin
/// değil; arkadaşın adı ([L10n.mascotPreviewFriend]) ARB'de duruyor.
const int kPersonaPreviewDays = 12;

/// Örnek cümlelerin çekildiği senaryo. Dört personanın da aynı senaryodan
/// konuşması şart: tasarımın tek işi tonların farkını göstermek, farklı
/// senaryolardan cümleler kıyaslanamaz.
const NotifyKind kPersonaPreviewKind = NotifyKind.friendStreak;

/// Personanın kullanıcıya görünen adı. Biçim `<Persona> Kimo`: maskot tek,
/// değişen ses tonu.
String personaName(L10n l, Mascot m) => switch (m) {
      Mascot.evHanimi => l.mascotNameEvHanimi,
      Mascot.arabeskci => l.mascotNameArabeskci,
      Mascot.sanayiUstasi => l.mascotNameSanayiUstasi,
      Mascot.ceo => l.mascotNameCeo,
    };

/// Tek cümlelik ton tarifi.
String personaTone(L10n l, Mascot m) => switch (m) {
      Mascot.evHanimi => l.mascotToneEvHanimi,
      Mascot.arabeskci => l.mascotToneArabeskci,
      Mascot.sanayiUstasi => l.mascotToneSanayiUstasi,
      Mascot.ceo => l.mascotToneCeo,
    };

/// Kartta gösterilen örnek bildirim.
///
/// Havuzdaki `friend_streak` metninin ilk varyantıyla aynı cümle, ama ARB'den
/// geliyor: bu cümle kullanıcı HENÜZ persona seçmeden görünmek zorunda ve
/// önbellek soğukken (yeni kurulum) ekran boş kalamaz. Kilit ekranı önizlemesi
/// ise canlı havuzdan okuyor — orada gerçek bildirimi göstermek anlamlı.
String personaSample(L10n l, Mascot m) {
  final String ad = l.mascotPreviewFriend;
  const int n = kPersonaPreviewDays;
  return switch (m) {
    Mascot.evHanimi => l.mascotSampleEvHanimi(ad, n),
    Mascot.arabeskci => l.mascotSampleArabeskci(ad, n),
    Mascot.sanayiUstasi => l.mascotSampleSanayiUstasi(ad, n),
    Mascot.ceo => l.mascotSampleCeo(ad, n),
  };
}

/// Seçilebilir persona satırı. Onboarding adımı ve ayarlardaki alt sayfa aynı
/// bileşeni kullanıyor — iki yerde iki farklı kart, tonların karşılaştırmasını
/// öğrenilmiş bir düzenden çıkarırdı.
class PersonaCard extends StatelessWidget {
  const PersonaCard({
    super.key,
    required this.mascot,
    required this.selected,
    required this.onTap,
  });

  final Mascot mascot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    final Color fg = selected ? c.actionText : c.ink;
    return Semantics(
      selected: selected,
      button: true,
      child: KimoCard(
        radius: Radii.card,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md,
        ),
        color: selected ? c.actionTint : c.card,
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Radio(selected: selected),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(personaName(l, mascot),
                      style: t.section.copyWith(color: fg)),
                  const SizedBox(height: Gap.xs),
                  Text(
                    '“${personaSample(l, mascot)}”',
                    style: t.caption
                        .copyWith(color: selected ? c.actionText : c.inkSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 24px yuvarlak seçim göstergesi. Renk tek taşıyıcı değil: seçili kartın
/// zemini de değişiyor ve ada tik eşlik ediyor.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(top: Gap.xxs),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? c.actionTextStrong : Colors.transparent,
        border: Border.all(
          color: selected ? c.actionTextStrong : c.border,
          width: 2,
        ),
      ),
      child: selected
          ? KimoIcon(KimoIcons.check, size: 13, color: c.onAction)
          : null,
    );
  }
}

/// "Kilit ekranında böyle görünür" — seçilen sesin gerçek bir bildirim gibi
/// göründüğü önizleme.
///
/// Metni CANLI HAVUZDAN alıyor (karttakinden farklı bir varyant): ekranın tek
/// işi tonun nasıl duyulacağını göstermek, ve gerçek cümleyi göstermek bunun
/// en dürüst yolu. Havuz henüz inmediyse karttaki örneğe düşer.
class PersonaPreview extends StatelessWidget {
  const PersonaPreview({super.key, required this.mascot});

  final Mascot mascot;

  /// Kartlar `friend_streak`'in 0. varyantını gösteriyor; önizleme 1.'yi
  /// gösteriyor ki aynı cümle ekranda iki kez görünmesin.
  static const int _previewIdx = 1;

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    final String? raw =
        notificationLines.preview(kPersonaPreviewKind, mascot, _previewIdx);
    final String body = raw == null
        ? personaSample(l, mascot)
        : NotificationLines.fill(raw,
            ad: l.mascotPreviewFriend, n: kPersonaPreviewDays);

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: c.sunken,
        borderRadius: Radii.all(Radii.sheet),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: Gap.xs, bottom: Gap.sm),
            child: Text(l.mascotPreviewLabel.toUpperCase(), style: t.overline),
          ),
          KimoCard(
            radius: Radii.tile,
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.actionTint,
                    borderRadius: Radii.all(Radii.chip),
                  ),
                  // Tek maskot: persona değişince yüz değişmiyor.
                  child: const Kimo(size: 30),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Expanded(
                            child: Text('Kimo', style: t.captionStrong.copyWith(color: c.ink)),
                          ),
                          Text(l.mascotPreviewNow, style: t.caption),
                        ],
                      ),
                      const SizedBox(height: Gap.xxs),
                      Text(body, style: t.caption.copyWith(color: c.ink)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
