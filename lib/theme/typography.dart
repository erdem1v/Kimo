import 'package:flutter/material.dart';

import 'tokens.dart';

/// Tipografi ölçeği — tek kaynak.
///
/// İki aile: başlık ve sayı için **Baloo2**, gövde ve etiket için **DMSans**.
/// Boyutlar onaylanan tasarımdan alındı; ekranlar `TextStyle` uydurmaz,
/// `context.t.<rol>` üzerinden alır.
///
/// Bütün sayaçlar `tabular-nums` kullanır: XP ve seri değişirken düzen kaymaz.
@immutable
class KimoTypography extends ThemeExtension<KimoTypography> {
  const KimoTypography({
    required this.display,
    required this.title,
    required this.heading,
    required this.section,
    required this.button,
    required this.buttonSmall,
    required this.tabLabel,
    required this.numberXl,
    required this.numberLarge,
    required this.numberMedium,
    required this.numberSmall,
    required this.body,
    required this.bodyStrong,
    required this.label,
    required this.caption,
    required this.captionStrong,
    required this.overline,
  });

  /// Onboarding ve kutlama başlığı (32/700).
  final TextStyle display;

  /// Ekran başlığı — "Bugün", "Hatalarım" (27/700).
  final TextStyle title;

  /// Kart başlığı (24/700).
  final TextStyle heading;

  /// Bölüm başlığı (18/600).
  final TextStyle section;

  /// Birincil buton etiketi (20/700). İki satıra sığar.
  final TextStyle button;

  /// İkincil buton / sheet aksiyonu (15.5/600).
  final TextStyle buttonSmall;

  /// Alt sekme etiketi (12/600).
  final TextStyle tabLabel;

  /// Çember göbeğindeki büyük sayaç (44/700, tabular).
  final TextStyle numberXl;

  /// Kart içi büyük sayı (25/700, tabular).
  final TextStyle numberLarge;

  /// Liste sonu sayısı (20/700, tabular).
  final TextStyle numberMedium;

  /// HUD hapı sayısı (16/700, tabular).
  final TextStyle numberSmall;

  /// Gövde metni (15/400).
  final TextStyle body;

  /// Vurgulu satır başlığı (14.5/600).
  final TextStyle bodyStrong;

  /// Form etiketi / satır adı (15/600).
  final TextStyle label;

  /// Yardımcı metin (13/400).
  final TextStyle caption;

  /// Vurgulu yardımcı metin (12.5/600).
  final TextStyle captionStrong;

  /// Üst etiket — "TYT · MATEMATİK" (11/700, büyük harf, geniş aralık).
  final TextStyle overline;

  static const String _head = 'Baloo2';
  static const String _body = 'DMSans';
  static const List<FontFeature> _tnum = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// Palete göre çözülmüş ölçek. Renk baştan gömülür; ekran yalnızca
  /// istisnai durumda `copyWith(color: ...)` yapar.
  factory KimoTypography.from(KimoColors c) {
    return KimoTypography(
      display: TextStyle(
        fontFamily: _head,
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w700,
        color: c.ink,
      ),
      title: TextStyle(
        fontFamily: _head,
        fontSize: 27,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: c.ink,
      ),
      heading: TextStyle(
        fontFamily: _head,
        fontSize: 24,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: c.ink,
      ),
      section: TextStyle(
        fontFamily: _head,
        fontSize: 18,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: c.ink,
      ),
      button: TextStyle(
        fontFamily: _head,
        fontSize: 20,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: c.onAction,
      ),
      buttonSmall: TextStyle(
        fontFamily: _body,
        fontSize: 15.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: c.ink,
      ),
      tabLabel: TextStyle(
        fontFamily: _head,
        fontSize: 12,
        height: 1.1,
        fontWeight: FontWeight.w600,
        color: c.navIdle,
      ),
      numberXl: TextStyle(
        fontFamily: _head,
        fontSize: 44,
        height: 1,
        fontWeight: FontWeight.w700,
        fontFeatures: _tnum,
        color: c.ink,
      ),
      numberLarge: TextStyle(
        fontFamily: _head,
        fontSize: 25,
        height: 1.1,
        fontWeight: FontWeight.w700,
        fontFeatures: _tnum,
        color: c.ink,
      ),
      numberMedium: TextStyle(
        fontFamily: _head,
        fontSize: 20,
        height: 1.1,
        fontWeight: FontWeight.w700,
        fontFeatures: _tnum,
        color: c.ink,
      ),
      numberSmall: TextStyle(
        fontFamily: _head,
        fontSize: 16,
        height: 1,
        fontWeight: FontWeight.w700,
        fontFeatures: _tnum,
        color: c.ink,
      ),
      body: TextStyle(
        fontFamily: _body,
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: c.ink,
      ),
      bodyStrong: TextStyle(
        fontFamily: _body,
        fontSize: 14.5,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: c.ink,
      ),
      label: TextStyle(
        fontFamily: _body,
        fontSize: 15,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: c.ink,
      ),
      caption: TextStyle(
        fontFamily: _body,
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: c.inkSecondary,
      ),
      captionStrong: TextStyle(
        fontFamily: _body,
        fontSize: 12.5,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: c.inkSecondary,
      ),
      overline: TextStyle(
        fontFamily: _body,
        fontSize: 11,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: c.inkMuted,
      ),
    );
  }

  @override
  KimoTypography copyWith({
    TextStyle? display,
    TextStyle? title,
    TextStyle? heading,
    TextStyle? section,
    TextStyle? button,
    TextStyle? buttonSmall,
    TextStyle? tabLabel,
    TextStyle? numberXl,
    TextStyle? numberLarge,
    TextStyle? numberMedium,
    TextStyle? numberSmall,
    TextStyle? body,
    TextStyle? bodyStrong,
    TextStyle? label,
    TextStyle? caption,
    TextStyle? captionStrong,
    TextStyle? overline,
  }) {
    return KimoTypography(
      display: display ?? this.display,
      title: title ?? this.title,
      heading: heading ?? this.heading,
      section: section ?? this.section,
      button: button ?? this.button,
      buttonSmall: buttonSmall ?? this.buttonSmall,
      tabLabel: tabLabel ?? this.tabLabel,
      numberXl: numberXl ?? this.numberXl,
      numberLarge: numberLarge ?? this.numberLarge,
      numberMedium: numberMedium ?? this.numberMedium,
      numberSmall: numberSmall ?? this.numberSmall,
      body: body ?? this.body,
      bodyStrong: bodyStrong ?? this.bodyStrong,
      label: label ?? this.label,
      caption: caption ?? this.caption,
      captionStrong: captionStrong ?? this.captionStrong,
      overline: overline ?? this.overline,
    );
  }

  @override
  KimoTypography lerp(covariant ThemeExtension<KimoTypography>? other, double t) {
    if (other is! KimoTypography) return this;
    TextStyle s(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return KimoTypography(
      display: s(display, other.display),
      title: s(title, other.title),
      heading: s(heading, other.heading),
      section: s(section, other.section),
      button: s(button, other.button),
      buttonSmall: s(buttonSmall, other.buttonSmall),
      tabLabel: s(tabLabel, other.tabLabel),
      numberXl: s(numberXl, other.numberXl),
      numberLarge: s(numberLarge, other.numberLarge),
      numberMedium: s(numberMedium, other.numberMedium),
      numberSmall: s(numberSmall, other.numberSmall),
      body: s(body, other.body),
      bodyStrong: s(bodyStrong, other.bodyStrong),
      label: s(label, other.label),
      caption: s(caption, other.caption),
      captionStrong: s(captionStrong, other.captionStrong),
      overline: s(overline, other.overline),
    );
  }
}

/// `Theme.of(context).extension<KimoTypography>()!` kısayolu.
extension KimoTypographyX on BuildContext {
  KimoTypography get t => Theme.of(this).extension<KimoTypography>()!;
}
