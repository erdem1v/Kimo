import 'package:ai_yks_coach/theme/app_theme.dart';
import 'package:ai_yks_coach/theme/tokens.dart';
import 'package:ai_yks_coach/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Token'lar tasarımdan birebir alındı. Bir değerin sessizce kayması ekranların
/// tamamını etkiler ve gözle fark edilmesi zordur; bu yüzden sabitleniyorlar.
void main() {
  group('palet — onaylanan tasarımın değerleri', () {
    test('açık tema zemin/yüzey/mürekkep', () {
      const KimoColors c = KimoColors.light;
      expect(c.page, const Color(0xFFFDFAF6));
      expect(c.card, const Color(0xFFFFFFFF));
      expect(c.sunken, const Color(0xFFF3EDE4));
      expect(c.cardShadow, const Color(0xFFEFE7DC));
      expect(c.border, const Color(0xFFE7E1D7));
      expect(c.ink, const Color(0xFF191713));
      expect(c.inkSecondary, const Color(0xFF5C564C));
      expect(c.inkMuted, const Color(0xFF6E675C));
    });

    test('koyu tema ters çevirme değil, sıcak grafit', () {
      const KimoColors c = KimoColors.dark;
      expect(c.page, const Color(0xFF17140F));
      expect(c.card, const Color(0xFF221E19));
      expect(c.sunken, const Color(0xFF2C2620));
      expect(c.border, const Color(0xFF3A332B));
      expect(c.ink, const Color(0xFFF7F3EE));
      expect(c.inkSecondary, const Color(0xFFB8B0A4));
      expect(c.inkMuted, const Color(0xFFA59D92));
    });

    test('mercan tek birincil aksiyon rengi ve iki temada da aynı', () {
      expect(KimoColors.light.action, const Color(0xFFF0522F));
      expect(KimoColors.dark.action, const Color(0xFFF0522F));
      expect(KimoColors.light.actionShadow, const Color(0xFFB0351A));
      expect(KimoColors.dark.actionShadow, const Color(0xFFB0351A));
    });

    test('aksan asla küçük metin rengi değil: metin varyantı ayrı', () {
      // Tasarım kuralı — mercan dolgu üstünde okunmuyor, metin için koyu ton.
      expect(KimoColors.light.actionText, const Color(0xFFB0351A));
      expect(KimoColors.light.actionText, isNot(KimoColors.light.action));
      // Koyu temada aynı ton okunmaz; açık varyant kullanılır.
      expect(KimoColors.dark.actionText, const Color(0xFFFF9273));
    });

    test('nane hâkimiyet, bal ara durum', () {
      expect(KimoColors.light.mint, const Color(0xFF1B9B6B));
      expect(KimoColors.light.mintText, const Color(0xFF0E6E4C));
      expect(KimoColors.light.mintTint, const Color(0xFFE6F6EE));
      expect(KimoColors.light.honey, const Color(0xFFF2A93B));
      expect(KimoColors.light.honeyText, const Color(0xFF8A5A12));
      expect(KimoColors.light.honeyTint, const Color(0xFFFFF3D9));
    });

    test('iki temada yüzeyler birbirinden ayrışır', () {
      const KimoColors l = KimoColors.light;
      const KimoColors d = KimoColors.dark;
      expect(l.page, isNot(d.page));
      expect(l.card, isNot(d.card));
      expect(l.ink, isNot(d.ink));
      // Aynı temada zemin ile kart da ayrışmalı, yoksa kart kaybolur.
      expect(l.page, isNot(l.card));
      expect(d.page, isNot(d.card));
      expect(l.sunken, isNot(l.card));
      expect(d.sunken, isNot(d.card));
    });

    test('lerp iki paleti karıştırabiliyor (tema geçişi)', () {
      final KimoColors mid = KimoColors.light.lerp(KimoColors.dark, 0.5);
      expect(mid.page, isNot(KimoColors.light.page));
      expect(mid.page, isNot(KimoColors.dark.page));
    });
  });

  group('biçim token’ları', () {
    test('yarıçaplar tasarımdaki ölçekte', () {
      expect(Radii.chip, 13);
      expect(Radii.pill, 16);
      expect(Radii.tile, 18);
      expect(Radii.card, 20);
      expect(Radii.button, 22);
      expect(Radii.sheet, 24);
    });

    test('dokunma hedefleri erişilebilirlik taahhüdünü karşılıyor', () {
      // Tasarım: birincil 58, ikincil satır 52, en küçük ikon butonu 44.
      expect(Sizes.buttonMin, 58);
      expect(Sizes.rowMin, greaterThanOrEqualTo(48));
      expect(Sizes.iconTap, greaterThanOrEqualTo(44));
    });

    test('kabartma 5px, basınca 4px iner (iniş kabartmayı aşamaz)', () {
      expect(Sizes.lip, 5);
      expect(Sizes.lipPressed, 4);
      expect(Sizes.lipPressed, lessThanOrEqualTo(Sizes.lip));
    });
  });

  group('tipografi', () {
    test('başlık ve sayı Baloo2, gövde DMSans', () {
      final KimoTypography t = KimoTypography.from(KimoColors.light);
      expect(t.title.fontFamily, 'Baloo2');
      expect(t.heading.fontFamily, 'Baloo2');
      expect(t.numberXl.fontFamily, 'Baloo2');
      expect(t.button.fontFamily, 'Baloo2');
      expect(t.body.fontFamily, 'DMSans');
      expect(t.caption.fontFamily, 'DMSans');
      expect(t.overline.fontFamily, 'DMSans');
    });

    test('bütün sayaçlar tabular: XP değişirken düzen kaymaz', () {
      final KimoTypography t = KimoTypography.from(KimoColors.light);
      for (final TextStyle s in <TextStyle>[
        t.numberXl,
        t.numberLarge,
        t.numberMedium,
        t.numberSmall,
      ]) {
        expect(
          s.fontFeatures,
          contains(const FontFeature.tabularFigures()),
          reason: '${s.fontSize}px sayaç',
        );
      }
    });

    test('metin renkleri paletten gelir', () {
      final KimoTypography light = KimoTypography.from(KimoColors.light);
      final KimoTypography dark = KimoTypography.from(KimoColors.dark);
      expect(light.body.color, KimoColors.light.ink);
      expect(dark.body.color, KimoColors.dark.ink);
      expect(light.caption.color, KimoColors.light.inkSecondary);
    });
  });

  group('tema kurulumu', () {
    test('her iki tema da token uzantılarını taşır', () {
      for (final ThemeData theme in <ThemeData>[
        AppTheme.light(),
        AppTheme.dark(),
      ]) {
        expect(theme.extension<KimoColors>(), isNotNull);
        expect(theme.extension<KimoTypography>(), isNotNull);
      }
    });

    test('zemin rengi paletle aynı', () {
      expect(AppTheme.light().scaffoldBackgroundColor, KimoColors.light.page);
      expect(AppTheme.dark().scaffoldBackgroundColor, KimoColors.dark.page);
    });

    test('parlaklık doğru kuruluyor', () {
      expect(AppTheme.light().brightness, Brightness.light);
      expect(AppTheme.dark().brightness, Brightness.dark);
    });
  });
}
