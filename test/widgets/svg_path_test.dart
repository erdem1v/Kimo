import 'dart:ui' as ui;

import 'package:ai_yks_coach/widgets/kit/kimo_icons.dart';
import 'package:ai_yks_coach/widgets/kit/svg_path.dart';
import 'package:flutter_test/flutter_test.dart';

/// İkonların geometrisi tasarımdan gelen SVG yol verisiyle tanımlı. Ayrıştırıcı
/// sessizce yanlış çizerse kimse fark etmez — bu yüzden veriyi test ediyoruz,
/// görüntüyü değil.
void main() {
  group('sayı dilbilgisi', () {
    test('ayırıcısız ondalık iki sayıya bölünür: "1.2.8"', () {
      // SVG kuralı: `L1.2.8` = (1.2, 0.8). Açgözlü okuma "1.2.8" deneyip
      // patlıyordu; alev ikonu tam olarak bu yüzden çizilmiyordu.
      final ui.Path p = parseSvgPath('M0 0L1.2.8');
      final ui.Rect b = p.getBounds();
      expect(b.right, closeTo(1.2, 1e-6));
      expect(b.bottom, closeTo(0.8, 1e-6));
    });

    test('işaret ayırıcı yerine geçer: "0-7.2"', () {
      final ui.Path p = parseSvgPath('M0 0L0-7.2');
      expect(p.getBounds().top, closeTo(-7.2, 1e-6));
    });

    test('üstel gösterim okunur', () {
      final ui.Path p = parseSvgPath('M0 0L1e1 0');
      expect(p.getBounds().right, closeTo(10, 1e-6));
    });
  });

  group('komut kapsamı', () {
    test('örtük tekrar: M sonrası koordinat çifti L sayılır', () {
      final ui.Path p = parseSvgPath('M0 0 5 0 5 5');
      final ui.Rect b = p.getBounds();
      expect(b.right, closeTo(5, 1e-6));
      expect(b.bottom, closeTo(5, 1e-6));
    });

    test('göreli komutlar birikimli çalışır', () {
      final ui.Path p = parseSvgPath('M2 2l3 0l0 3');
      final ui.Rect b = p.getBounds();
      expect(b.left, closeTo(2, 1e-6));
      expect(b.right, closeTo(5, 1e-6));
      expect(b.bottom, closeTo(5, 1e-6));
    });

    test('yay komutu daire üretir (iki yarım yay)', () {
      // cx=12, cy=8.5, r=3.6 — profil ikonundaki göz.
      final ui.Path p =
          parseSvgPath('M8.4 8.5a3.6 3.6 0 1 0 7.2 0a3.6 3.6 0 1 0-7.2 0');
      final ui.Rect b = p.getBounds();
      // `Path.getBounds()` KONTROL NOKTALARINA göre sınır döndürür, eğrinin
      // kendisine değil. Yay tam çeyreklere bölündüğünde kontrol noktaları
      // sınır kutusunun üstünde kalır, yani ikisi çakışır ve tolerans dar
      // olabilir. Bu iddia aynı zamanda parçalama toleransını da koruyor:
      // yarım çember 3 parçaya bölünürse kutu her yönde ~0,16 birim büyür.
      expect(b.left, closeTo(8.4, 0.01));
      expect(b.right, closeTo(15.6, 0.01));
      expect(b.top, closeTo(4.9, 0.01));
      expect(b.bottom, closeTo(12.1, 0.01));
    });

    test('bilinmeyen komut sessizce yutulmaz', () {
      expect(() => parseSvgPath('M0 0 X5 5'), throwsFormatException);
    });

    test('kapatma başlangıç noktasına döner', () {
      final ui.Path p = parseSvgPath('M1 1L5 1L5 5Z');
      expect(p.getBounds().left, closeTo(1, 1e-6));
    });
  });

  group('ikon kataloğu', () {
    test('her yol ayrıştırılabiliyor ve 24 birimlik ızgarada kalıyor', () {
      expect(KimoIcons.all, isNotEmpty);
      for (final KimoIconData icon in KimoIcons.all) {
        expect(icon.paths, isNotEmpty);
        for (final String d in icon.paths) {
          final ui.Path path = parseSvgPath(d);
          final ui.Rect b = path.getBounds();
          // Hiçbir ikon 24 birimlik ızgaranın dışına taşmıyor; tolerans dar
          // tutuldu ki yanlış bir yol verisi sessizce geçmesin.
          expect(b.left, greaterThanOrEqualTo(-0.01), reason: d);
          expect(b.top, greaterThanOrEqualTo(-0.01), reason: d);
          expect(b.right, lessThanOrEqualTo(24.01), reason: d);
          expect(b.bottom, lessThanOrEqualTo(24.01), reason: d);
          // Dikey/yatay tek çizgilerde bir kenar sıfırdır; ikisi birden değil.
          expect(b.width + b.height, greaterThan(0.0), reason: d);
        }
      }
    });

    test('kontur ikonlarının kalınlığı tasarım aralığında', () {
      for (final KimoIconData icon in KimoIcons.all) {
        if (icon.filled) continue;
        expect(
          icon.strokeWidth,
          inInclusiveRange(1.8, 2.6),
          reason: icon.paths.first,
        );
      }
    });
  });
}
